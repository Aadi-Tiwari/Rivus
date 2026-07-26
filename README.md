# PipeTrace

**Tells a water crew which measurement to take next, says out loud when pressure cannot
identify one pipe, and searches valve configurations before anyone turns one.**

A district is losing treated water underground. Thirty-five junctions could be
responsible. Checking one costs about an hour of a two-person crew, and opening the
wrong street costs about twenty thousand dollars. PipeTrace runs a real EPANET
hydraulic simulation for every candidate leak, keeps a belief over all of them on a Jac
graph, and ranks every measurement the crew could take by how much uncertainty it would
remove per crew-hour.

Built at JacHacks SF, 26 July 2026.

---

## What is actually true

Measured by `jac/evaluate.jac` across every junction used as a hidden leak, three seeds,
105 incidents per arm, with the truth model deliberately different from the model used
to diagnose:

| probe strategy | top-1 | top-3 | top-5 | search distance | crew time |
|---|---|---|---|---|---|
| max information gain | 20.0% | 50.5% | 63.8% | 2.22 hops | 70 min |
| bits per crew-hour | 15.2% | 45.7% | 57.1% | 2.70 hops | 18 min |
| random probes (control) | 8.6% | 32.4% | 46.7% | 3.92 hops | 96 min |

Read that honestly:

- Information-gain probing lands **43% closer** to the leak than probing at random.
- **The exact junction is identified 20% of the time.** PipeTrace does not claim to find
  the pipe, and never should. If that number ever jumps above 50%, something has gone
  circular and the run should be thrown away.
- Cost-aware probing is a real tradeoff, not a free win: it saves 78 crew-minutes per
  incident against random and gives up 0.49 hops of accuracy. Both arms are reported.
- The random control arm is not decoration. Without it, "information gain helps" is an
  unfalsifiable claim.

## Why the diagnosis is not circular

If the readings came from the same simulator used to invert them, the result would mean
nothing. So `StageIncident` perturbs the truth model before taking the crew's readings —
demands at 8% CV, pipe roughness at 10% CV — and adds 0.35 psi of gauge noise on top.
The diagnosis then runs against the *nominal* model. The two genuinely diverge by more
than the noise floor.

## Isolation, answered twice

Before a crew turns a valve, a walker grows valve rings outward from the break and every
configuration is screened two ways that share no code:

1. **Graph reachability** — flood the Jac graph from the supply through pipe edges that
   are still open. Anything unreachable has lost service, by pure topology.
2. **Pressure-dependent hydraulics** — run EPANET in PDA mode on the same valve
   configuration and count junctions below service pressure.

They agree on every configuration searched. A disagreement would be a finding, not
something to paper over.

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

`rm -rf .jac` matters: Jac persists the graph to disk between runs, so a second run
stacks another copy of the network onto root and every count silently doubles.

The incident board reads `web/trace.json`, which `jac/main.jac` writes from the run you
just did. Nothing in it is hardcoded.

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
