include simulate;
import from hydraulics { topology, run }

with entry {
    t = topology();
    cands = t["junctions"];
    gauges = t["gauges"];
    pids = [];
    for pp in t["pipes"] { pids.append(pp["id"]); }
    print("leak_gpm  exact%  top5%  mean_entropy  median_divergence  gate");
    for em in [100.0, 200.0, 400.0, 800.0, 1600.0] {
        set_leak(em);
        model = build_forward_model(cands);
        hit = 0; top5 = 0; hsum = 0.0; dsum = 0.0; n = 0; gateok = 0;
        for seed in [1, 2, 3] {
            for c in cands {
                inc = stage_incident(c, gauges, pids, seed);
                d = divergence_stats(model[c], inc["perturbed"], gauges);
                dsum += d["median"];
                if d["ok"] { gateok += 1; }
                post = posterior(inc["readings"], model, cands, gauges);
                r = rank_desc(post);
                if r[0] == c { hit += 1; }
                if c in r[:5] { top5 += 1; }
                hsum += entropy(post);
                n += 1;
            }
        }
        print("  ", em, " ", round(100.0 * hit / n, 1), " ", round(100.0 * top5 / n, 1),
              " ", round(hsum / n, 3), " ", round(dsum / n, 3), " ", round(100.0 * gateok / n, 0));
    }
}
