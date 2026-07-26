"""Honest measurement.

Sweeps every possible hidden leak location and runs the full probing loop on each,
three ways: maximum information gain, information per crew-hour, and random probing as
a control. A claim that "choosing probes well helps" means nothing without the control,
so the control is not optional here.

    jac run jac/evaluate.jac
"""

include harness;


glob EVAL_SEEDS: int = 3;     # 35 locations x 3 seeds = 105 incidents per arm


with entry {
    for n in [root-->] { del n; }
    ing = root spawn IngestNetwork();
    fm = root spawn BuildForwardModel();
    juncs = of_type([root-->], Junction);

    print(f"\nPipeTrace evaluation");
    print(f"  {len(NODES)} junctions, every one used as a hidden leak in turn");
    print(f"  sigma {sigma():.2f} psi, truth model perturbed "
          f"(demand {DEMAND_CV:.0%} CV, roughness {ROUGH_CV:.0%} CV)");
    print(f"  3 probes per incident, {EVAL_DRAWS} Monte Carlo draws, {EVAL_SEEDS} seeds\n");

    arms = ["info", "cost", "adaptive", "random"];
    labels = {"info": "max information gain", "cost": "bits per crew-hour",
              "adaptive": "adaptive stopping", "random": "random probes (control)"};
    stats = {};
    for a in arms { stats[a] = [0, 0, 0, 0, 0.0, 0, 0]; }  # n, top1, top3, top5, hops, crew, probes

    idx = 0;
    rep = 0;
    while rep < EVAL_SEEDS {
      for truth in NODES {
        root spawn StageIncident(truth=truth, seed=1000 + rep * 977 + idx);
        root spawn CheckNonCircularity(truth=truth);
        for a in arms {
            r = root spawn RunArm(truth=truth, arm=a);
            s = stats[a];
            s[0] += 1;
            if r.rank == 1 { s[1] += 1; }
            if r.rank <= 3 { s[2] += 1; }
            if r.rank <= 5 { s[3] += 1; }
            s[4] += r.hops;
            s[5] += int(r.crew_min);
            s[6] += r.spent;
        }
        idx += 1;
        if idx % 20 == 0 { print(f"  ... {idx}/{EVAL_SEEDS * len(NODES)} incidents"); }
      }
      rep += 1;
    }

    dv = DIVERGENCE;
    med = dv["sum"] / dv["n"];
    frac = 100.0 * dv["cleared"] / dv["n"];
    print("");
    print("  non-circularity gate: perturbed truth departs from the nominal model by",
          round(med, 2), "psi median, worst incident", round(dv["worst"], 2),
          "psi, against", GAUGE_NOISE, "psi gauge noise;", round(frac, 0),
          "percent of gauges clear the floor");
    if dv["worst"] <= GAUGE_NOISE {
        print("  GATE WARNING: at least one incident does not clear gauge noise.");
    } else {
        print("  GATE PASS: every incident diverges by more than gauge noise.");
    }

    print(f"\n  after 3 probes ({stats['info'][0]} incidents per arm):");
    for a in arms {
        s = stats[a];
        n = s[0];
        print(f"  {labels[a]:<26} top-1 {100.0 * s[1] / n:5.1f}%   "
              f"top-3 {100.0 * s[2] / n:5.1f}%   top-5 {100.0 * s[3] / n:5.1f}%   "
              f"mean {s[4] / n:.2f} hops   {s[5] / n:.0f} crew-min   "
              f"{s[6] / n:.1f} probes");
    }
    i = stats["info"];
    c = stats["cost"];
    d = stats["random"];
    lift = (1.0 - (i[4] / i[0]) / (d[4] / d[0])) * 100.0;
    print(f"\n  search distance {i[4] / i[0]:.2f} hops vs {d[4] / d[0]:.2f} random "
          f"-> {lift:.0f}% closer");
    print(f"  cost-aware saves {(d[5] - c[5]) / d[0]:.0f} crew-min per incident against "
          f"random and {(i[5] - c[5]) / i[0]:.0f} against max-info, and gives up "
          f"{(c[4] - i[4]) / c[0]:.2f} hops. That is a real tradeoff, not a free win.");
    print(f"  exact junction identified {100.0 * i[1] / i[0]:.0f}% of the time at best. "
          f"PipeTrace never claims to find the pipe.\n");
}
