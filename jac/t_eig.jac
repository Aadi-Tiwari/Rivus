include simulate;
import from hydraulics { topology, run }
with entry {
    t = topology(); cands = t["junctions"]; gauges = t["gauges"];
    pids = []; for pp in t["pipes"] { pids.append(pp["id"]); }
    set_leak(400.0);
    model = build_forward_model(cands);
    for ms in [0.5, 1.3, 2.5] {
        CFG["model_sigma"] = ms;
        inc = stage_incident(cands[9], gauges, pids, 1);
        flat = posterior(inc["readings"], model, cands, []);
        vals = [];
        for g in gauges {
            vals.append(round(expected_information(g, flat, model, cands, inc["readings"], []), 3));
        }
        print("model_sigma", ms, " prior entropy", round(entropy(flat),3), " EIG per gauge:", vals);
    }
}
