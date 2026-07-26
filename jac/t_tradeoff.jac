include simulate;
import from hydraulics { topology, run }
with entry {
    t = topology(); cands = t["junctions"]; gauges = t["gauges"];
    pids = []; for pp in t["pipes"] { pids.append(pp["id"]); }
    set_leak(400.0); CFG["model_sigma"] = 1.30;
    model = build_forward_model(cands);
    print("THE TRADEOFF: perturbation strength vs both accuracy and the non-circularity gate");
    print("rough_cv  exact%  top5%  median_diverg  gate_pass%   (chance = 4.5%)");
    for rcv in [0.0, 0.01, 0.02, 0.04, 0.06, 0.10] {
        CFG["rough_cv"] = rcv;
        hit = 0; t5 = 0; n = 0; ds = 0.0; ok = 0;
        for seed in [1, 2, 3] {
            for c in cands {
                inc = stage_incident(c, gauges, pids, seed);
                d = divergence_stats(model[c], inc["perturbed"], gauges);
                ds += d["median"];
                if d["ok"] { ok += 1; }
                post = posterior(inc["readings"], model, cands, gauges);
                r = rank_desc(post);
                if r[0] == c { hit += 1; }
                if c in r[:5] { t5 += 1; }
                n += 1;
            }
        }
        print("  ", rcv, "  ", round(100.0*hit/n,1), "  ", round(100.0*t5/n,1),
              "  ", round(ds/n,3), "  ", round(100.0*ok/n,0));
    }
}
