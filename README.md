# Rivus

**Tells a water crew which measurement to take next, says out loud when pressure cannot
identify one pipe, and searches valve configurations before anyone turns one.**

A district is losing treated water underground. Thirty-five junctions could be
responsible. Checking one costs about an hour of a two-person crew, and opening the
wrong street costs about twenty thousand dollars. Rivus runs a real EPANET
hydraulic simulation for every candidate leak, keeps a belief over all of them on a Jac
graph, and ranks every measurement the crew could take by how much uncertainty it would
remove per crew-hour.

Built at JacHacks SF, 26 July 2026.

---

## What is actually true

This section changed late in the day, and the change is the most important thing in the
repository.

### The claim that did not survive

An earlier version of this README reported that information-gain probing landed **43%
closer** to the leak than random probing. **That number was an artifact and it has been
withdrawn.**

Person B built a gate (`CheckNonCircularity` in `jac/simulate.jac`) that measures whether
the evidence the crew reads actually departs from the forward model's own prediction. It
failed: median divergence was 0.04 psi against a 0.35 psi gauge-noise floor. The cause was
that `OBSERVED` differenced two snapshots taken under the *same* perturbation, so the
perturbation cancelled in residual space. The diagnosis was very nearly inverting its own
simulator, which is exactly the thing the perturbation was supposed to prevent.

The fix was physics, not tuning. Three sources of model error, separated by whether they
survive differencing:

| source | survives differencing? | how it is modelled |
|---|---|---|
| pipe roughness | no — persistent, same error both times | shared draw |
| district demand | **yes** — the baseline is a different day | independent draws |
| leak size | **yes** — the diagnosis assumes `LEAK_C` | drawn per incident, 30% CV |

### What the corrected numbers say

105 incidents per arm, every junction used as a hidden leak, three seeds:

| probe strategy | top-1 | top-3 | top-5 | search distance | crew time |
|---|---|---|---|---|---|
| max information gain | 9.5% | 23.8% | 29.5% | 4.90 hops | 66 min |
| bits per crew-hour | 3.8% | 12.4% | 21.0% | 5.31 hops | 18 min |
| adaptive stopping | 8.6% | 21.0% | 32.4% | 4.92 hops | 62 min |
| random probes (control) | 5.7% | 18.1% | 30.5% | 4.54 hops | 100 min |

**On Net2 we cannot claim that information-gain probing beats random probing.** Top-1
9.5% vs 5.7% has z = 1.04 — not resolvable at n=105 — and mean search distance is
actually worse than the control.

### So we tested whether that is the method or the network

Net2 is a 35-junction toy where 179 of 210 candidate pairs are hydraulically
indistinguishable. Almost nothing is left for a probe policy to exploit. `jac/scale.jac`
runs the identical measurement on **Net3: 92 junctions, 117 pipes, 192.6 L/s, five
sources**, with the leak scaled to the larger district.

| | Net2 (35 junctions) | Net3 (92 junctions) |
|---|---|---|
| indistinguishable pairs, 12-candidate sample | 24 / 66 | **8 / 66** |
| top-1, information gain vs random | 8.6% vs 8.6% | **19.6% vs 5.4%** |
| top-5, information gain vs random | 37.1% vs 28.6% | **46.7% vs 22.8%** |
| search distance | 4.49 vs 5.14 hops (+13%) | **3.98 vs 6.27 hops (+37%)** |
| statistically resolvable? | no, z = 0.0 and 0.76 | **yes, z = 2.98 and 3.52 (p<0.01)** |

**The method works. It needs a network with enough hydraulically distinguishable
structure, and Net2 does not have it.** On Net3 information-gain probing identifies the
exact junction 3.6× more often than chance and halves the search distance, and both
results are significant at p<0.01.

That is a narrower claim than the 43% we withdrew, and unlike that one it survives its
own gate and a control arm.

There is one suggestive pattern worth naming rather than hiding: information-gain probing
concentrates belief, so when it is right it is very right, and when it is wrong it is
*confidently* wrong further away — which is precisely why the identifiability report below
is not a nicety. A system whose confident answers are unreliable has to say when it cannot
separate candidates.

### What is verified and does hold

These are deterministic. They do not move between runs, and they are the parts of the
project that survived contact with the gate:

- **36 EPANET simulations in 0.22s**, one per candidate leak.
- **Identifiability**: 179 of 210 surviving pairs cannot be separated by any single gauge
  anywhere in the network. Some differ by under 0.05 psi against 0.61 psi of observation
  noise. The engine names the pairs.
- **Isolation search**: four valve configurations, each screened twice by methods sharing
  no code, with every disagreement between them reconciled and explained.
- **Field intake** refuses a note rather than inventing a pressure reading.

## Isolation, answered twice

Before a crew turns a valve, a walker grows valve rings outward from the break and every
configuration is screened two ways that share no code:

1. **Graph reachability** — flood the Jac graph from the supply through pipe edges that
   are still open. Anything unreachable has lost service, by pure topology.
2. **Pressure-dependent hydraulics** — run EPANET in PDA mode on the same valve
   configuration and count junctions below service pressure.

They do not always agree, and that turned out to be the most useful thing about running
both. The two methods answer different questions — topology reports who is **cut off**,
hydraulics reports who is **below service pressure** — so the engine reconciles every
disagreement instead of printing a bare boolean:

- *starved while still connected* — closing valves raised head loss enough to drop a
  junction below service pressure without disconnecting it. Only the hydraulic run can
  see this.
- *cut off but already dry* — the junction was below service pressure before the work
  started, so it had no service to lose. Only the topology run counts it.

**The cross-check caught a real bug.** EPANET cannot solve a hydraulically disconnected
subnetwork; instead of failing it returned pressures in the millions of psi. Our screen
read those as "comfortably above 20 psi" and reported **0 customers affected when 12 had
been cut off**. The graph walker said 12. That contradiction is what surfaced it.
Non-physical solver output is now treated as loss of service, including at the critical
facility, where a solver artifact would otherwise have accepted a plan that strands a
hospital.

```
REJECTED  tight ring                  2 valves  hospital 78.77 → 0.00 psi   6/35 out  agree=True
ACCEPTED  tight ring + backup supply  2 valves  hospital 78.77 → 37.64 psi  1/35 out  agree=True
REJECTED  wider ring                  5 valves  hospital 78.77 → 0.00 psi   7/35 out  agree=True
ACCEPTED  wider ring + backup supply  5 valves  hospital 78.77 → 37.64 psi  3/35 out  agree=True
→ chosen: tight ring + backup supply
```

This is **modeled service-impact screening, not a safety certification.** An operator
decides.

## How it uses Jac

The water network is not modelled as a graph for convenience. It *is* a graph: junctions
are nodes, pipes are typed `Pipe` edges, tanks and reservoirs are `Source` nodes, and
walkers traverse the same topology the water does. Belief about the leak lives on
`Hypothesis` nodes as graph state.

**94% of the code is Jac.** The single Python file is 65 lines and exists only because
EPANET is a C library.

| file | what lives there |
|---|---|
| `jac/network.jac` | schema, scenario constants, ingest walker |
| `jac/graphops.jac` | probe ranking, identifiability, isolation islands, valve search |
| `jac/simulate.jac` | forward model, Bayesian posterior, expected information gain |
| `jac/intake.jac` | `by llm()` field-note parsing |
| `jac/evaluate.jac` | the measurement harness and its random control |
| `py/hydraulics.py` | EPANET boundary. Nothing else. |

The parts that could not be done any other way:

- **Connectivity under edge removal.** Closing a valve is deleting an edge; asking who
  still has water is a reachability question. A walker answers it by traversal.
- **Valve-ring search.** A crew cannot always close the valves either side of a break —
  one may be seized or missing from the map. Which valves form the next ring outward is
  a question about the graph, and `ValveRings` walks it.
- **Identifiability.** Junctions on the same branch push pressure around almost
  identically, so no measurement separates them. 179 of 210 surviving pairs differ by
  less than the 1.22 psi we can distinguish — some by under 0.05 psi. The engine names
  the pairs instead of picking a confident winner.

**Where the language model runs:** one place, `jac/intake.jac`, doing one job — turning
a crew's radio note into a typed `Observation` node. It refuses a note rather than
inventing a pressure reading, and falls back to a deterministic parser with a visible
warning when no model is configured. Nothing it produces decides anything; EPANET and
Bayes produce every number.

## Run it

```bash
python3 -m venv .venv && ./.venv/bin/pip install -r requirements.txt
rm -rf .jac && PYTHONPATH=$PWD ./.venv/bin/jac run jac/main.jac      # full investigation
rm -rf .jac && PYTHONPATH=$PWD ./.venv/bin/jac run jac/evaluate.jac  # the table above
rm -rf .jac && PYTHONPATH=$PWD ./.venv/bin/jac run jac/intake.jac    # field-note parsing
open web/index.html                                                  # incident board
```

Or one command each: `./demo.sh`, `./demo.sh eval`, `./demo.sh intake`, `./demo.sh test`.

```
$ ./demo.sh test
17/17 passed
```

Several of those tests exist to fail if the project is ever quietly made to overclaim:
that the truth model really does diverge from the model used to diagnose, that restored
pressure never exceeds the undisturbed baseline, that identifiability is reported as
pairs rather than merged clusters, and that both isolation methods agree on every plan
the search generates.

`rm -rf .jac` matters: Jac persists the graph to disk between runs, so a second run
stacks another copy of the network onto root and every count silently doubles.

The incident board reads `web/trace.json`, which `jac/main.jac` writes from the run you
just did. Nothing in it is hardcoded.

`web/standalone.html` is the same board with that trace inlined — one 33 KB file, no
fetch, no server, no external requests. That is the version to host.

`jac/serve.jac` exposes the same walkers over REST via `jac start jac/serve.jac`.
Honest caveat: the 0.16.7 dev server gates every walker endpoint behind auth and the
`__specs__ { has auth: bool = False; }` block does not open them on this version, so the
endpoints return 401 without a token. The CLI and the static board are the paths that
work today.

## Honest limits

- Net2 is an EPA sample network, not a utility's calibrated model. It draws 20.4 L/s, so
  a leak large enough to beat the gauge noise floor is necessarily a large fraction of
  district demand — the default is a catastrophic main break, and the demo says so.
- The critical facility (node 35) and the emergency interconnect (60 m head, tied in at
  node 30) are scenario configuration, declared in `network.jac` and printed at runtime.
  They are not read from the network file.
- Sequential pressure-sensor leak localization is published prior art, and the ~43%
  search-distance improvement measured here is consistent with what the literature
  reports for mobile-sensor relocation. The localization mathematics is not new. What is
  assembled here is the field loop: next best test scored per crew-hour, an explicit
  report of what pressure cannot resolve, and a searched isolation plan cross-checked
  two ways.

## Jac notes for anyone reading the source

Traps hit while building this, each of which cost real time:

- Typed edges use single-dash arrows: `[->:Pipe:->]`, not `-->`.
- Backticks break the lexer anywhere, including inside a docstring. The backtick
  type-filter form and ``with `root entry`` both fail on jaclang 0.16.7 / Python 3.13.
- A docstring inside a `def` or `can` body needs a trailing `;`. An archetype-level
  docstring must not have one.
- Inside a walker, `can` declares an ability and `def` declares a method.
- Assigning to a `glob` inside a scope silently creates a local. Mutate a dict instead.
- `disengage` kills the whole walker; `skip` aborts just the current node.
- Edges have no `.target` — zip `[edge n ->:Pipe:->]` with `[n ->:Pipe:->]` positionally.
- `jac check` reports dozens of errors on files that run perfectly. Trust `jac run`.
