"""Where does information-gain probing actually beat random probing?

The advantage depends on how well the utility knows today's demand. A district metered
area has an inlet flow meter, so demand is partly observed, not unknown. This measures
the lift over a random control across that range instead of picking one value and
hoping. One seed per location (35 incidents per point) to keep it quick.
"""
include graphops;

glob EVAL_DRAWS: int = 300;

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



glob CVS: list = [0.05, 0.08, 0.12, 0.18, 0.25];

with entry {
    for n in [root-->] { del n; }
    root spawn IngestNetwork();
    root spawn BuildForwardModel();
    print(f"\n  demand CV | mismatch | gate | info hops | random hops | lift | info top-5");
    for cv in CVS {
        mis = 0.0; ih = 0.0; rh = 0.0; it5 = 0; k = 0;
        for (i, t) in enumerate(NODES) {
            root spawn StageIncident(truth=t, seed=1000 + i, demand_cv=cv);
            g = root spawn CheckNonCircularity(truth=t);
            mis += g.median;
            a = root spawn RunArm(truth=t, arm="info");
            ih += a.hops;
            if a.rank <= 5 { it5 += 1; }
            root spawn StageIncident(truth=t, seed=1000 + i, demand_cv=cv);
            b = root spawn RunArm(truth=t, arm="random");
            rh += b.hops;
            k += 1;
        }
        gate = "fail";
        if mis / k > GAUGE_NOISE { gate = "PASS"; }
        lift = (1.0 - (ih / k) / (rh / k)) * 100.0;
        print(f"     {cv:.2f}   |  {mis/k:.3f}  | {gate} |   {ih/k:.2f}    |    {rh/k:.2f}     | {lift:+.0f}% |   {100.0*it5/k:.0f}%");
    }
}
