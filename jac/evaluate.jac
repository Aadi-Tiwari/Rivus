"""Honest measurement.

Sweeps every possible hidden leak location and runs the full probing loop on each,
three ways: maximum information gain, information per crew-hour, and random probing as
a control. A claim that "choosing probes well helps" means nothing without the control,
so the control is not optional here.

    jac run jac/evaluate.jac
"""

include graphops;


walker ResetBelief {
    """Returns every hypothesis to the uniform prior and clears measured flags, so the
    next arm starts from the same place as the last one."""
    can reset with entry {
        hyps = of_type([-->], Hypothesis);
        for h in hyps { h.prob = 1.0 / len(hyps); }
        for j in of_type([-->], Junction) { j.measured = False; j.reading_psi = 0.0; }
    }
}


walker Hops {
    """Shortest path length in pipe hops, by breadth-first traversal of the graph."""
    has target: str;
    has depth: dict = {};
    has answer: int = 99;

    can start with Junction entry {
        if here.name in self.depth { skip; }
        d = 0;
        if len(self.depth) > 0 { d = self.depth["__cur"]; }
        self.depth[here.name] = d;
        if here.name == self.target { self.answer = d; disengage; }
        self.depth["__cur"] = d + 1;
        visit [->:Pipe:->];
        visit [<-:Pipe:<-];
    }
}


def hops_between(juncs: list, a: str, b: str) -> int {
    """Breadth-first hop count. Walkers in Jac traverse depth-first by default, so the
    layer bookkeeping above is approximate; this does an explicit BFS over the same
    Pipe edges and is what the reported numbers use.""";
    if a == b { return 0; }
    byname = {};
    for j in juncs { byname[j.name] = j; }
    if a not in byname or b not in byname { return 99; }
    seen = [a];
    frontier = [byname[a]];
    d = 0;
    while len(frontier) > 0 and d < 40 {
        d += 1;
        nxt = [];
        for n in frontier {
            for m in [n ->:Pipe:->] + [n <-:Pipe:<-] {
                if isinstance(m, Junction) and m.name not in seen {
                    if m.name == b { return d; }
                    seen.append(m.name);
                    nxt.append(m);
                }
            }
        }
        frontier = nxt;
    }
    return 99;
}


walker RunArm {
    """One investigation under one probe-selection policy."""
    has truth: str;
    has arm: str = "info";
    has probes: int = 3;
    has rank: int = 0;
    has hops: int = 0;
    has survivors: int = 0;
    has crew_min: float = 0.0;
    has spent: int = 0;

    can run with entry {
        root spawn ResetBelief();
        juncs = of_type([-->], Junction);
        crew = "1";
        step = 0;
        budget = self.probes;
        if self.arm == "adaptive" { budget = ADAPTIVE_MAX; }
        while step < budget {
            chosen = "";
            bits = 0.0;
            mins = 0.0;
            if self.arm == "random" {
                pool = [];
                for j in juncs { if not j.measured { pool.append(j.name); } }
                chosen = pool[random.randrange(len(pool))];
                for j in juncs {
                    if j.name == crew { c = j; }
                }
                for j in juncs {
                    if j.name == chosen {
                        mins = math.hypot(j.x - c.x, j.y - c.y) / CREW_SPEED;
                        if mins < 1.0 { mins = 1.0; }
                    }
                }
            } else {
                sc = root spawn ScoreProbes(crew_at=crew,
                                            cost_aware=(self.arm == "cost"),
                                            draws=EVAL_DRAWS);
                best = sc.ranked[0];
                chosen = best[1];
                bits = best[2];
                mins = best[3];
                # Adaptive arm: a probe that buys less than STOP_BITS is a crew sent
                # out for nothing. Stop rather than spend the budget for its own sake.
                if self.arm == "adaptive" and step > 0 and bits < STOP_BITS { break; }
            }
            reading = read_gauge(chosen);
            tp = root spawn TakeProbe(location=chosen, reading=reading);
            self.crew_min += mins;
            self.survivors = tp.survivors;
            crew = chosen;
            step += 1;
        }
        self.spent = step;

        hyps = of_type([-->], Hypothesis);
        pairs = [];
        for h in hyps { pairs.append([h.prob, h.location]); }
        pairs.sort(reverse=True);
        r = 1;
        for p in pairs {
            if p[1] == self.truth { self.rank = r; }
            r += 1;
        }
        self.hops = hops_between(juncs, self.truth, pairs[0][1]);
    }
}


glob EVAL_DRAWS: int = 300;   # matches the demo's Monte Carlo resolution
glob EVAL_SEEDS: int = 3;     # 35 locations x 3 seeds = 105 incidents per arm
glob ADAPTIVE_MAX: int = 3;   # same budget as the other arms, so it can only stop EARLY
glob STOP_BITS: float = 0.35; # a probe buying less than this is not worth a crew dispatch


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
