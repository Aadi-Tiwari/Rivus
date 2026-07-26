import math;
import from hydraulics { topology, run }

glob CFG = {"noise": 0.35, "leak_gpm": 400.0, "model_sigma": 1.30, "rough_cv": 0.10, "dem_cv": 0.08};

def lcg_next(state: int) -> int {
    "Deterministic linear congruential generator so runs are reproducible without Python.";
    return (1103515245 * state + 12345) % 2147483648;
}

def lcg_unit(state: int) -> tuple {
    "Return a uniform in [0,1) and the advanced generator state.";
    s = lcg_next(state);
    return (s / 2147483648.0, s);
}

def lcg_normal(state: int) -> tuple {
    "Irwin-Hall normal approximation. Adequate for 8-10 percent parameter perturbation.";
    total = 0.0;
    s = state;
    for _ in range(12) {
        pair = lcg_unit(s);
        total += pair[0];
        s = pair[1];
    }
    return (total - 6.0, s);
}

def build_forward_model(candidates: list) -> dict {
    "Nominal predicted gauge pressures for every candidate leak site. One EPANET solve each.";
    model = {};
    for c in candidates {
        model[c] = run(c, CFG["leak_gpm"], None, None);
    }
    return model;
}

def stage_incident(truth: str, gauges: list, pipes: list, seed: int) -> dict {
    "Crew readings from a PERTURBED model: demands at 8 percent CV and roughness at 10 percent CV.";
    s = seed * 7919 + 13;
    dscale = {};
    for g in gauges {
        pair = lcg_normal(s);
        dscale[g] = 1.0 + CFG["dem_cv"] * pair[0];
        s = pair[1];
    }
    rscale = {};
    for p in pipes {
        pair = lcg_normal(s);
        rscale[p] = 1.0 + CFG["rough_cv"] * pair[0];
        s = pair[1];
    }
    perturbed = run(truth, CFG["leak_gpm"], dscale, rscale);
    readings = {};
    for g in gauges {
        pair = lcg_normal(s);
        readings[g] = perturbed[g] + CFG["noise"] * pair[0];
        s = pair[1];
    }
    return {"readings": readings, "perturbed": perturbed};
}

def total_sigma() -> float {
    "Gauge noise and forward-model error add in quadrature. Using gauge noise alone makes the posterior confidently wrong.";
    return math.sqrt(CFG["noise"] * CFG["noise"] + CFG["model_sigma"] * CFG["model_sigma"]);
}

def log_like(readings: dict, pred: dict, seen: list) -> float {
    "Gaussian log likelihood of the observed gauges under one candidate.";
    ll = 0.0;
    sg = total_sigma();
    for g in seen {
        r = (readings[g] - pred[g]) / sg;
        ll -= 0.5 * r * r;
    }
    return ll;
}

def posterior(readings: dict, model: dict, candidates: list, seen: list) -> dict {
    "Normalised posterior over candidate leak sites given the gauges probed so far.";
    lls = {};
    best = -1.0e18;
    for c in candidates {
        v = log_like(readings, model[c], seen);
        lls[c] = v;
        if v > best { best = v; }
    }
    total = 0.0;
    w = {};
    for c in candidates {
        e = math.exp(lls[c] - best);
        w[c] = e;
        total += e;
    }
    post = {};
    for c in candidates {
        post[c] = w[c] / total;
    }
    return post;
}

def entropy(post: dict) -> float {
    "Shannon entropy of the posterior in bits.";
    h = 0.0;
    for k in post.keys() {
        p = post[k];
        if p > 0.0 {
            h -= p * math.log(p, 2);
        }
    }
    return h;
}

def expected_information(gauge: str, post: dict, model: dict, candidates: list,
                         readings: dict, seen: list) -> float {
    "Expected entropy reduction from probing this gauge, marginalised over predicted readings.";
    h0 = entropy(post);
    exp_h = 0.0;
    for c in candidates {
        pc = post[c];
        if pc < 1.0e-6 { continue; }
        hypo = {};
        for g in seen { hypo[g] = readings[g]; }
        hypo[gauge] = model[c][gauge];
        seen2 = [];
        for g in seen { seen2.append(g); }
        seen2.append(gauge);
        exp_h += pc * entropy(posterior(hypo, model, candidates, seen2));
    }
    return h0 - exp_h;
}

def divergence_stats(nominal: dict, perturbed: dict, gauges: list) -> dict {
    "Gate: the perturbed truth must diverge from the nominal model by more than gauge noise.";
    diffs = [];
    for g in gauges {
        diffs.append(abs(nominal[g] - perturbed[g]));
    }
    diffs.sort();
    n = len(diffs);
    total = 0.0;
    above = 0;
    for d in diffs {
        total += d;
        if d > CFG["noise"] { above += 1; }
    }
    return {"n": n, "median": diffs[n // 2], "mean": total / n,
            "max": diffs[n - 1], "frac_above_noise": above / n,
            "ok": diffs[n // 2] > CFG["noise"]};
}

def rank_desc(post: dict) -> list {
    "Candidates ordered by descending posterior probability. Avoids lambda syntax entirely.";
    items = [];
    for k in post.keys() {
        items.append((post[k], k));
    }
    items.sort();
    items.reverse();
    out = [];
    for it in items {
        out.append(it[1]);
    }
    return out;
}

def set_leak(v: float) -> None {
    "Mutate the config dict. Rebinding a glob inside a scope would silently create a local.";
    CFG["leak_gpm"] = v;
}
