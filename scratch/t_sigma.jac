include simulate;
import from hydraulics { topology, run }
with entry {
    t = topology(); cands = t["junctions"]; gauges = t["gauges"];
    pids = []; for pp in t["pipes"] { pids.append(pp["id"]); }
    set_leak(400.0);
    model = build_forward_model(cands);
    print("model_sigma  exact%  top5%  mean_entropy   (leak=400gpm, 66 incidents)");
    for ms in [0.01, 0.5, 1.3, 2.5, 5.0] {
        CFG["model_sigma"] = ms;
        hit = 0; t5 = 0; hs = 0.0; n = 0;
        for seed in [1, 2, 3] {
            for c in cands {
                inc = stage_incident(c, gauges, pids, seed);
                post = posterior(inc["readings"], model, cands, gauges);
                r = rank_desc(post);
                if r[0] == c { hit += 1; }
                if c in r[:5] { t5 += 1; }
                hs += entropy(post); n += 1;
            }
        }
        print("   ", ms, "  ", round(100.0*hit/n,1), "  ", round(100.0*t5/n,1), "  ", round(hs/n,3));
    }
}
