# Person B deliverable, written 12:20 Jul 26

## Read this first: what I could and could not do

**The repo is not on this machine.** It lives in the Wizard Hackathon working
folder on Abhinav's Mac, under his home directory. I
searched this whole Windows profile and found no `.jac` files except VS
Code's bundled examples. So I could not edit `jac/simulate.jac`,
`jac/evaluate.jac` or `py/hydraulics.py` directly.

**What I did instead:** wrote the logic for all three jobs as standalone
Jac and **actually ran it** on the local jaclang install. The code below
is executed output, not proposed code. Two files in this folder, `t1.jac`
and `t2.jac`, reproduce it.

**What is still unverified**, and you must check it on the Mac:

- I have no access to `BuildForwardModel`, `StageIncident`, `read_gauge`,
  `expected_information`, `snapshot`, `topology`, `sample_index`,
  `TakeProbe`, `credible_set`, or the globals `OBSERVED`, `META`, `NODES`.
  Every call site marked `ADAPT` below needs its real signature.
- Local jac is the Windows pip build. Yours is a venv jac on Mac and may
  differ. The syntax I used is deliberately conservative: no backticks
  anywhere, no typed-edge arrows, no glob rebinding.
- The stopping threshold below is on a synthetic information scale. It
  **must be recalibrated** against your real `expected_information()`
  values before it means anything.

---

# JOB 1: prove the non-circularity, do not assert it

The risk a judge will probe: if diagnosis inverts the same simulator that
produced the evidence, the result is circular and meaningless. Your
defence is that `StageIncident` perturbs demands at 8% CV and roughness
at 10% CV. That defence is only real if the perturbed and nominal
baselines actually diverge by **more than the 0.35 psi gauge noise**.
Otherwise the perturbation is cosmetic.

This runs, verified locally:

```jac
def divergence_stats(nominal: dict, perturbed: dict, noise: float) -> dict {
    "Per-gauge absolute divergence between the nominal and perturbed forward models.";
    diffs = [];
    for g in nominal.keys() {
        if g in perturbed {
            diffs.append(abs(nominal[g] - perturbed[g]));
        }
    }
    if len(diffs) == 0 {
        return {"n": 0, "ok": False};
    }
    diffs.sort();
    n = len(diffs);
    total = 0.0;
    for d in diffs {
        total += d;
    }
    above = 0;
    for d in diffs {
        if d > noise {
            above += 1;
        }
    }
    return {"n": n, "median": diffs[n // 2], "mean": total / n,
            "min": diffs[0], "max": diffs[n - 1],
            "frac_above_noise": above / n, "ok": diffs[n // 2] > noise};
}
```

**Verified output** on a 5-gauge sample:

```
{'n': 5, 'median': 1.4, 'mean': 1.3, 'min': 0.1, 'max': 1.9,
 'frac_above_noise': 0.8, 'ok': True}
```

Median divergence 1.4 psi against 0.35 psi noise, 80% of gauges clear.
That is the shape of answer you want on stage.

**ADAPT:** feed it the real thing. `nominal` is gauge pressures from the
nominal forward model, `perturbed` is gauge pressures from the model
`StageIncident` actually perturbed. Both keyed by gauge id.

**One methodological upgrade, do this.** A single draw can clear the
noise floor by luck. Run the check across the same 3 seeds the evaluation
uses and report the distribution, then gate on the **worst** seed rather
than the mean. A check that cannot fail is not a check.

---

# JOB 2: adaptive stopping as a fourth arm

Also verified locally, including the entropy math:

```jac
import math;

def entropy(post: dict) -> float {
    "Shannon entropy of the posterior over candidate leak sites, in bits.";
    h = 0.0;
    for k in post.keys() {
        p = post[k];
        if p > 0.0 {
            h -= p * math.log(p, 2);
        }
    }
    return h;
}

def should_stop(eig: float, threshold: float, probes_taken: int, max_probes: int) -> bool {
    "Stop when the next probe buys less than threshold bits, or the budget is spent.";
    if probes_taken >= max_probes {
        return True;
    }
    return eig < threshold;
}
```

**Verified output:** entropy of a flat 4-way posterior is exactly 2.0
bits, which is the correct `log2(4)`, and a sharp posterior gives 0.6175.
The math is right.

**The result that matters**, replaying a decaying information sequence
`[1.20, 0.61, 0.18, 0.04, 0.01]`:

| Threshold | Probes taken | Bits gained |
|---|---|---|
| 0.50 | **2** | 1.81 |
| 0.15 | 3 | 1.99 |
| 0.05 | 3 | 1.99 |
| 0.00 | 5 | 2.04 |
| fixed-3 arm | 3 | 1.99 |

**At threshold 0.50 you get 91% of the information for two-thirds of the
probes.** That is the honest claim for this arm, and it is a good one,
because every probe is a crew dispatched to a street.

**Frame it correctly or it looks like a failure.** This arm will not beat
fixed-3 on accuracy, and it is not supposed to. Its win is **equal
accuracy at lower cost**. So the evaluation table must report probes used
as a column, not just hops and top-5. If you only report accuracy, an
arm that ties on accuracy looks pointless.

**ADAPT:** call `expected_information()` for the best candidate probe at
each step and feed it in as `eig`. Recalibrate the threshold: print the
real EIG values for the first three probes across a few incidents, then
set the threshold between the typical second and third values.

---

# JOB 3: the reporting table

Report all four arms with these columns. Do not drop the random control.

| Arm | Mean hops to leak | Top-5 | Exact junction | Mean probes |
|---|---|---|---|---|
| random control | 3.92 | 46.7% | | 3 |
| max information gain | 2.22 | 63.8% | 20% | 3 |
| (your third arm) | | | | 3 |
| adaptive stopping | | | | **measure this** |

Rules you were given and should keep: if an arm performs worse, say it
performed worse. Never claim you find the exact pipe. **If top-1 ever
jumps above 50%, stop and investigate**, because at 105 incidents per arm
that is far more likely to be a leak in the evaluation than a real gain.

---

# Traps I respected in the code above

No backticks anywhere including docstrings. No typed-edge arrows, so
nothing to get wrong there. Every docstring sits inside a `def` body and
carries the trailing `;`. No `glob` rebinding, everything returns a fresh
dict instead of mutating outer state. No `disengage`. `jac check` will
report false errors on this; trust `jac run`. And `rm -rf .jac` before
every run, which I did for both test files.
