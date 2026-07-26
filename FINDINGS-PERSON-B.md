# Person B: working build and findings, 13:40 Jul 26

Built on Windows because the real repo is on Abhinav's Mac. This is an
**independent second implementation** of the same idea, which is exactly
what you want for cross-checking numbers. Everything below is measured
output from code in this folder, not estimates.

Run it: `cd Projects/Rivus && rm -rf .jac && PYTHONPATH=$PWD/py jac run jac/evaluate.jac`

## What was built

| File | Lines | Role |
|---|---|---|
| `py/hydraulics.py` | ~55 | EPANET calls only, via wntr. No numerical logic. |
| `jac/simulate.jac` | ~190 | Forward model, seeded perturbation, likelihood, posterior, entropy, expected information gain, non-circularity gate. All maths in Jac. |
| `jac/evaluate.jac` | ~120 | BFS hop table, four probing arms including the random control. |

Network is **Anytown_multipointcurves** (22 junctions, 43 pipes, 8
gauges), a real published benchmark bundled with wntr. I screened all 33
bundled networks and only 8 produce physically valid hydraulics; plain
`Anytown.inp` diverges to 1e25 and is unusable.

## Three findings, in order of how much they matter

### 1. The non-circularity gate and the accuracy are in direct conflict

This is the headline and it is uncomfortable. Sweeping roughness
perturbation strength, 66 incidents per row, chance is 4.5%:

| roughness CV | exact% | top5% | median divergence | gate pass% |
|---|---|---|---|---|
| 0.00 | 40.9 | 80.3 | 0.341 | 32 |
| 0.02 | 34.8 | 75.8 | 0.346 | 36 |
| **0.04** | **13.6** | **45.5** | **0.490** | **70** |
| 0.06 | 4.5 | 31.8 | 0.706 | 100 |
| 0.10 (your spec) | 4.5 | 30.3 | 1.294 | 100 |

**At the 10% roughness CV your spec calls for, my implementation sits at
exactly chance.** The system only beats chance where the gate fails, and
only passes the gate where the system stops working. The crossover is
around 4% CV: 13.6% exact, three times chance, with the gate passing 70%
of the time. That is the defensible operating point.

**Check this on your build before you quote 20% exact and 63.8% top-5.**
If those numbers come from a weaker perturbation than the gate requires,
that is precisely the question a judge will ask. My network, gauge
placement and perturbation code all differ from yours, so this is a
warning to verify, not a verdict on your numbers.

### 2. Using gauge noise alone in the likelihood makes it confidently wrong

With realistic perturbation on, a likelihood built on the 0.35 psi gauge
noise gives **entropy 0.000 while being wrong 95% of the time.** Certainty
and error at once, which is the worst possible failure for a product whose
pitch is that it reports what it cannot know.

Fix, now in `simulate.jac`: gauge noise and forward-model error add in
quadrature, `sigma = sqrt(0.35^2 + model_sigma^2)`, with `model_sigma`
set from the measured divergence (1.30 psi here).

**Sigma changes calibration, not ranking.** Measured across sigma 0.01 to
5.0: exact stays 4.5% and top-5 stays 30.3% at every value, while mean
entropy moves 0.0 to 4.342 bits. So honest uncertainty is free. There is
no accuracy argument for staying overconfident.

### 3. Information gain only helps when sigma is honest

Expected information gain per gauge, same incident:

| model_sigma | EIG range across 8 gauges |
|---|---|
| 0.5 | 0.006 to 0.627 bits |
| 1.3 | 0.000 to 0.226 bits |
| 2.5 | 0.000 to 0.040 bits |

At sigma 2.5 no gauge carries information, so max-infogain degenerates to
random. Set sigma from measured divergence, not defensively.

## Four-arm evaluation, run honestly

66 incidents per arm, leak 400 gpm, model_sigma 1.30, roughness CV 0.10:

| Arm | exact% | top5% | mean hops | mean probes |
|---|---|---|---|---|
| random control | 7.6 | 31.8 | 2.09 | 3.0 |
| max information gain | 4.5 | 27.3 | 2.18 | 3.0 |
| adaptive stopping | 4.5 | 22.7 | 2.18 | **1.0** |
| all 8 gauges | 4.5 | 30.3 | 2.18 | 8.0 |

**Reported as measured: the treatment arms did not beat the control in
this regime.** All three sit at 4.5%, which is 1/22, chance. Random at
7.6% is noise above chance, not a real win.

The diagnostic that explains it: **using all 8 gauges (4.5%) is no better
than 3 random ones (7.6%).** When more data does not help, the forward
model is misspecified rather than the policy being bad. That is finding 1
restated, and it is why the roughness CV question has to be settled first.

Adaptive stopping did what it was supposed to, spending 1.0 probes
instead of 3.0. In a regime where the arms actually separate, that is the
result worth having: comparable accuracy, one third of the crew
dispatches.

## Jac traps I hit, so you do not

- **Glob rebinding silently does nothing.** `set_emitter` wrote to a local
  and my first calibration sweep returned identical numbers across five
  leak sizes before I noticed. Everything is now a mutable `CFG` dict.
- **Lambdas inside `sorted(key=...)` do not parse.** Use an explicit
  `rank_desc` def that sorts `(prob, id)` tuples and reverses.
- Emitter-based leaks **saturate**: 0.5 and 30.0 gave identical 30 psi
  drops and drove junctions negative. Leaks are now added demand in GPM,
  which is linear and controllable.
- `rm -rf .jac` before every run or the graph stacks and counts double.

## Honest limits

Not verified: that any of this ports cleanly to your archetypes, since I
never saw `StageIncident`, `expected_information`, `read_gauge`,
`credible_set`, `OBSERVED`, `META` or `NODES`. Function names here
deliberately mirror yours so the mapping is obvious, but signatures will
differ. My gauge set is every third junction, which is arbitrary; real
gauge placement would change every number above.
