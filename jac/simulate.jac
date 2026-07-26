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
        base = snapshot(INP);
        n = len(NODES);
        for h in NODES {
            p = snapshot(INP, leak_node=h, leak_c=LEAK_C);
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

    The observations come from a PERTURBED model: demands and pipe roughness are
    shifted before the truth snapshot is taken. Without this the diagnosis would be
    inverting the same simulator that produced the evidence, which proves nothing.
    """
    has truth: str;
    has seed: int = 7;
    has leak_lps: float = 0.0;

    can stage with entry {
        random.seed(self.seed);
        dm = {};
        rm = {};
        topo = topology(INP);
        for j in topo["junctions"] { dm[j] = random.lognormvariate(0.0, DEMAND_CV); }
        for p in topo["pipes"] { rm[p[0]] = random.lognormvariate(0.0, ROUGH_CV); }

        base = snapshot(INP, demand_mult=dm, rough_mult=rm);
        leak = snapshot(INP, leak_node=self.truth, leak_c=LEAK_C,
                        demand_mult=dm, rough_mult=rm);
        OBSERVED.clear();
        for j in NODES { OBSERVED[j] = leak[j] - base[j]; }

        head_m = base[self.truth] / 1.4219702063247;
        if head_m < 0.0 { head_m = 0.0; }
        self.leak_lps = LEAK_C * math.sqrt(head_m) * 1000.0;

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
