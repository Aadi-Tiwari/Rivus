include simulate;
import from hydraulics { topology, run }

with entry {
    t = topology();
    cands = t["junctions"];
    gauges = t["gauges"];
    model = build_forward_model(cands);
    truth = cands[9];
    inc = stage_incident(truth, gauges, 1);
    print("truth junction:", truth);
    print("NON-CIRCULARITY:", divergence_stats(model[truth], inc["perturbed"], gauges));
    post = posterior(inc["readings"], model, cands, gauges);
    r = rank_desc(post);
    top = [];
    for c in r[:5] { top.append((c, round(post[c], 3))); }
    print("top5:", top);
    print("entropy bits:", round(entropy(post), 3), " truth rank:", r.index(truth) + 1);
    print("EIG of first 3 gauges from flat start:");
    flat = posterior(inc["readings"], model, cands, []);
    for g in gauges[:3] {
        print("   gauge", g, "->", round(expected_information(g, flat, model, cands, inc["readings"], []), 4), "bits");
    }
}
