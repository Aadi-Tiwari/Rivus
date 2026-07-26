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

def adaptive_run(eig_seq: list, threshold: float, max_probes: int) -> dict {
    "Replay a sequence of expected information gains under the stopping rule.";
    taken = 0;
    spent = 0.0;
    for eig in eig_seq {
        if should_stop(eig, threshold, taken, max_probes) {
            break;
        }
        taken += 1;
        spent += eig;
    }
    return {"probes": taken, "bits_gained": spent};
}

with entry {
    flat = {"a": 0.25, "b": 0.25, "c": 0.25, "d": 0.25};
    sharp = {"a": 0.90, "b": 0.05, "c": 0.03, "d": 0.02};
    print("entropy flat  (want 2.00):", round(entropy(flat), 4));
    print("entropy sharp (want low) :", round(entropy(sharp), 4));

    print("--- stopping rule on a decaying information sequence ---");
    seq = [1.20, 0.61, 0.18, 0.04, 0.01];
    for th in [0.50, 0.15, 0.05, 0.0] {
        r = adaptive_run(seq, th, 5);
        print("  threshold", th, "->", r);
    }
    print("fixed-3-probe arm always spends 3 probes for", round(seq[0] + seq[1] + seq[2], 3), "bits");
}
