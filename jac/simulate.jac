"""PipeTrace — simulation and belief.  [ OWNER: Person B ]

The EPANET boundary, the forward model, the Bayesian posterior, and expected
information gain. Everything here is numerical. Anything that reasons about network
connectivity belongs in graphops.jac, which Person A owns.

Keep this file small, and keep it in Jac: the posterior and the information-gain
estimate are walkers and defs on purpose. Moving them into Python would push the
project under the 40% Jac requirement.
"""

include network;


# ---------------------------------------------------------------- forward model
walker BuildForwardModel {
    """One EPANET run per candidate leak location.

    A leak anywhere moves pressure everywhere, so a single simulation yields the
    predicted reading at every possible probe site. That is why this is affordable.
    """
    has count: int = 0;
    has seconds: float = 0.0;

    can build with entry {
        import time;
        t0 = time.time();
        base = snapshot(inp());
        n = len(NODES);
        for h in NODES {
            p = snapshot(inp(), leak_node=h, leak_c=leak_c());
            sig = [];
            for j in NODES { sig.append(p[j] - base[j]); }
            here ++> Hypothesis(location=h, prob=1.0 / n, signature=sig);
            self.count += 1;
        }
        self.seconds = time.time() - t0;
        print(f"[forward] {self.count + 1} EPANET runs in {self.seconds:.2f}s "
              f"({(self.seconds / (self.count + 1)) * 1000:.0f} ms each)");
    }
}

glob OBSERVED: dict = {};
glob META: dict = {};   # mutated in place, unlike a glob rebind

walker StageIncident {
    """Hides a leak and produces what a crew would actually read.

    Person B measured the previous version of this and it failed its own gate: the
    baseline and the leak snapshot were taken under the SAME perturbation, so the
    perturbation cancelled in residual space. Median divergence from the nominal model
    was 0.04 psi against a 0.35 psi gauge-noise floor. The defence was cosmetic.

    The fix is physics, not a tuning knob. Three sources of mismatch, separated by
    whether they actually cancel when you difference two snapshots:

      roughness   persistent. The pipe is as rough today as it was when the baseline
                  was recorded, and our model is wrong about it in the same way both
                  times. This SHOULD cancel, and it does. Shared draw.
      demand      day to day. The historical baseline was recorded on a different day
                  under different consumption. This does NOT cancel. Independent draws.
      leak size   unknown. The diagnosis assumes LEAK_C; the actual break is whatever
                  it is. This does NOT cancel. Drawn per incident.

    That is what a crew's evidence actually looks like, and it is a materially harder
    problem than the version this replaces.
    """
    has truth: str;
    has seed: int = 7;
    has leak_lps: float = 0.0;
    has true_leak_c: float = 0.0;
    # a parameter, not a glob read: assigning to a glob inside a scope silently
    # creates a local in Jac, which made an earlier sweep of this value a no-op.
    has demand_cv: float = -1.0;

    can stage with entry {
        random.seed(self.seed);
        topo = topology(inp());
        dcv = self.demand_cv;
        if dcv < 0.0 { dcv = DEMAND_CV; }

        # persistent model error: same pipes, same wrong roughness, both snapshots
        rm = {};
        for p in topo["pipes"] { rm[p[0]] = random.lognormvariate(0.0, ROUGH_CV); }

        # demand differs between the historical baseline and today
        dm_hist = {};
        dm_now = {};
        for j in topo["junctions"] {
            dm_hist[j] = random.lognormvariate(0.0, dcv);
            dm_now[j] = random.lognormvariate(0.0, dcv);
        }

        # the break is whatever size it is; the forward model assumes LEAK_C
        self.true_leak_c = leak_c() * random.lognormvariate(0.0, LEAK_SIZE_CV);

        base = snapshot(inp(), demand_mult=dm_hist, rough_mult=rm);
        leak = snapshot(inp(), leak_node=self.truth, leak_c=self.true_leak_c,
                        demand_mult=dm_now, rough_mult=rm);
        OBSERVED.clear();
        for j in NODES { OBSERVED[j] = leak[j] - base[j]; }

        head_m = base[self.truth] / 1.4219702063247;
        if head_m < 0.0 { head_m = 0.0; }
        self.leak_lps = self.true_leak_c * math.sqrt(head_m) * 1000.0;

        # the junction the supply main ties into, for isolation flooding
        for p in topo["pipes"] {
            if p[1] in topo["sources"] { META["supply"] = p[2]; }
            elif p[2] in topo["sources"] { META["supply"] = p[1]; }
        }
    }
}


def read_gauge(location: str) -> float {
    """One field measurement: the true residual plus gauge noise.""";
    return OBSERVED[location] + random.gauss(0.0, GAUGE_NOISE);
}



def expected_information(mu: list, probs: list, draws: int) -> float {
    """Differential entropy of the predictive Gaussian mixture, by Monte Carlo.""";
    s = sigma();
    total = 0.0;
    i = 0;
    while i < draws {
        k = sample_index(probs);
        y = mu[k] + random.gauss(0.0, s);
        dens = 0.0;
        for (m, w) in zip(mu, probs) {
            dens += w * math.exp(-0.5 * ((y - m) / s) ** 2);
        }
        if dens < 1e-300 { dens = 1e-300; }
        total += -math.log2(dens);
        i += 1;
    }
    return total / draws;
}

def sample_index(probs: list) -> int {
    r = random.random();
    acc = 0.0;
    for (i, p) in enumerate(probs) {
        acc += p;
        if r <= acc { return i; }
    }
    return len(probs) - 1;
}



walker TakeProbe {
    """Applies one field measurement and updates belief on every hypothesis node."""
    has location: str;
    has reading: float;
    has survivors: int = 0;
    has entropy_bits: float = 0.0;
    has top: str = "";
    has top_prob: float = 0.0;

    can apply with entry {
        col = NODES.index(self.location);
        hyps = of_type([-->], Hypothesis);
        total = 0.0;
        for h in hyps {
            like = math.exp(-0.5 * ((self.reading - h.signature[col]) / sigma()) ** 2);
            h.prob = h.prob * like;
            total += h.prob;
        }
        if total <= 1e-300 {
            # Every hypothesis contradicted. Fall back to the prior rather than
            # invent a winner out of floating-point noise.
            for h in hyps { h.prob = 1.0 / len(hyps); }
        } else {
            for h in hyps { h.prob = h.prob / total; }
        }

        for j in of_type([-->], Junction) {
            if j.name == self.location {
                j.measured = True;
                j.reading_psi = self.reading;
            }
        }

        ent = 0.0;
        best = 0.0;
        for h in hyps {
            if h.prob > 0.0 { ent += -h.prob * math.log2(h.prob); }
            if h.prob > best { best = h.prob; self.top = h.location; }
        }
        self.entropy_bits = ent;
        self.top_prob = best;
        self.survivors = len(credible_set(hyps, 0.90));
    }
}


def credible_set(hyps: list, mass: float) -> list {
    """Smallest set of hypotheses holding 'mass' of the belief.""";
    pairs = [];
    for h in hyps { pairs.append([h.prob, h.location]); }
    pairs.sort(reverse=True);     # [prob, location] — prob leads
    out = [];
    acc = 0.0;
    for p in pairs {
        out.append(p[1]);
        acc += p[0];
        if acc >= mass { break; }
    }
    return out;
}

# ------------------------------------------------------------- identifiability


# ------------------------------------------------------- non-circularity evidence
glob DIVERGENCE: dict = {"n": 0, "sum": 0.0, "worst": 1e9, "cleared": 0};

walker CheckNonCircularity {
    """Proves the diagnosis is not inverting its own simulator.

    StageIncident draws the crew's readings from a perturbed model. That defence is
    only real if the perturbed residual actually departs from the nominal forward
    model by more than gauge noise. If it does not, the perturbation is cosmetic and
    the whole evaluation is circular. This measures the gap instead of asserting it.
    """
    has truth: str;
    has median: float = 0.0;
    has worst: float = 0.0;
    has cleared: float = 0.0;

    can check with entry {
        sig = [];
        for h in of_type([-->], Hypothesis) {
            if h.location == self.truth { sig = h.signature; }
        }
        if len(sig) == 0 { disengage; }
        diffs = [];
        for (i, j) in enumerate(NODES) {
            diffs.append(abs(OBSERVED[j] - sig[i]));
        }
        diffs.sort();
        n = len(diffs);
        above = 0;
        for d in diffs { if d > GAUGE_NOISE { above += 1; } }
        self.median = diffs[n // 2];
        self.worst = diffs[0];
        self.cleared = above / n;
        DIVERGENCE["n"] += 1;
        DIVERGENCE["sum"] += self.median;
        DIVERGENCE["cleared"] += self.cleared;
        if self.median < DIVERGENCE["worst"] { DIVERGENCE["worst"] = self.median; }
    }
}
