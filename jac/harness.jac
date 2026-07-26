"""Shared measurement harness.

One copy of the belief reset, the hop-distance metric, and the arm runner, used by both
evaluate.jac (the headline table) and envelope.jac (the sensitivity sweep). They were
duplicated, which meant a change to how an arm runs would silently stop the two from
measuring the same thing.
"""

include graphops;


glob EVAL_DRAWS: int = 300;   # Monte Carlo resolution, matches the demo
glob ADAPTIVE_MAX: int = 3;   # same budget as the other arms, so it can only stop EARLY
glob STOP_BITS: float = 0.35; # a probe buying less than this is not worth a dispatch


walker ResetBelief {
    """Returns every hypothesis to the uniform prior and clears measured flags, so the
    next arm starts from the same place as the last one."""
    can reset with entry {
        hyps = of_type([-->], Hypothesis);
        for h in hyps { h.prob = 1.0 / len(hyps); }
        for j in of_type([-->], Junction) { j.measured = False; j.reading_psi = 0.0; }
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
        # first junction in the network, not a hardcoded id: Net2 has a node "1"
        # and Net3 does not, and the hardcoded version crashed on the larger net.
        crew = NODES[0];
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


