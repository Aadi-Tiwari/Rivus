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

with entry {
    nominal = {"g1": 62.0, "g2": 58.5, "g3": 71.2, "g4": 49.8, "g5": 65.1};
    perturbed = {"g1": 63.4, "g2": 57.1, "g3": 72.9, "g4": 49.9, "g5": 63.2};
    print(divergence_stats(nominal, perturbed, 0.35));
}
