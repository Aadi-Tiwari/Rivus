"""PipeTrace — graph reasoning.  [ OWNER: Person A ]

Probe ranking, identifiability, and isolation islands. These are the parts that are
genuinely graph theory: connectivity under edge removal, and which junctions the
network's hydraulics fuse together so that no measurement can separate them.

Numerical helpers (posterior, expected information) come from simulate.jac.
"""

include simulate;


walker ScoreProbes {
    """Ranks every possible measurement by expected information gain.

    I(Y;H) = h(Y) - h(Y|H). The conditional term is the entropy of a single Gaussian
    and is identical at every location, so ranking by the predictive mixture entropy
    h(Y) ranks by information gain. Estimated by Monte Carlo, here, in Jac.
    """
    has crew_at: str = "1";
    has cost_aware: bool = True;
    has draws: int = 300;
    has ranked: list = [];

    can score with entry {
        hyps = of_type([-->], Hypothesis);
        probs = [];
        for h in hyps { probs.append(h.prob); }
        juncs = of_type([-->], Junction);
        crew = None;
        for j in juncs { if j.name == self.crew_at { crew = j; } }

        out = [];
        for (col, name) in enumerate(NODES) {
            target = None;
            for j in juncs { if j.name == name { target = j; } }
            if target == None or target.measured { continue; }

            mu = [];
            for h in hyps { mu.append(h.signature[col]); }
            bits = expected_information(mu, probs, self.draws);
            mins = self.travel(crew, target);
            score = bits;
            if self.cost_aware { score = bits / (mins / 60.0); }
            out.append([score, name, bits, mins]);
        }
        out.sort(reverse=True);   # [score, name, bits, mins] — score leads
        self.ranked = out;
    }

    def travel(a: Junction, b: Junction) -> float {
        d = math.hypot(b.x - a.x, b.y - a.y);
        m = d / CREW_SPEED;
        if m < 1.0 { return 1.0; }
        return m;
    }
}

walker CheckIdentifiability {
    """Reports what pressure measurement cannot resolve, and the sensor move that would.

    Two junctions on the same branch push pressure around almost identically everywhere.
    No probe sequence separates them, because the information is not there. Rather than
    hide that behind a confident top-1, this names the pairs.
    """
    has survivors: list = [];
    has blocked: list = [];
    has n_pairs: int = 0;
    has verdict: str = "";
    has advice_node: str = "";
    has advice_sep: float = 0.0;

    can check with entry {
        hyps = of_type([-->], Hypothesis);
        self.survivors = credible_set(hyps, 0.90);
        byloc = {};
        for h in hyps { byloc[h.location] = h; }

        threshold = 2.0 * sigma();
        n = len(self.survivors);
        self.n_pairs = n * (n - 1) // 2;

        a = 0;
        while a < n {
            b = a + 1;
            while b < n {
                sa = byloc[self.survivors[a]].signature;
                sb = byloc[self.survivors[b]].signature;
                worst = 0.0;
                where = "";
                for (i, name) in enumerate(NODES) {
                    d = abs(sa[i] - sb[i]);
                    if d > worst { worst = d; where = name; }
                }
                if worst < threshold {
                    # separation leads so a plain sort orders by how fused the pair is
                    self.blocked.append([worst, self.survivors[a],
                                         self.survivors[b], where]);
                }
                b += 1;
            }
            a += 1;
        }
        self.blocked.sort();

        # Best place for one more gauge: maximise the WORST pairwise separation, so
        # the winner separates every survivor rather than the easiest pair.
        best_node = "";
        best_sep = -1.0;
        for (i, name) in enumerate(NODES) {
            worst_here = 1e9;
            a2 = 0;
            while a2 < n {
                b2 = a2 + 1;
                while b2 < n {
                    d = abs(byloc[self.survivors[a2]].signature[i]
                            - byloc[self.survivors[b2]].signature[i]);
                    if d < worst_here { worst_here = d; }
                    b2 += 1;
                }
                a2 += 1;
            }
            if worst_here > best_sep { best_sep = worst_here; best_node = name; }
        }
        self.advice_node = best_node;
        self.advice_sep = best_sep;

        if n < 2 { self.verdict = "IDENTIFIED"; }
        elif best_sep >= threshold { self.verdict = "IDENTIFIABLE_WITH_ONE_MORE_SENSOR"; }
        elif len(self.blocked) == self.n_pairs {
            self.verdict = "NOT_IDENTIFIABLE_FROM_PRESSURE";
        } else { self.verdict = "PARTIALLY_IDENTIFIABLE"; }

        here ++> Finding(kind="identifiability", verdict=self.verdict,
                         detail=f"{len(self.blocked)} of {self.n_pairs} surviving pairs "
                                f"cannot be separated by any single gauge");
    }
}

# ------------------------------------------------------------------- isolation
walker FloodFromSource {
    """Finds every junction still fed, by walking open pipe edges.

    This is the isolation question answered as a graph traversal rather than a
    simulation: close a segment, flood the network from the supply, and whatever the
    walker cannot reach has lost service. The hydraulic model then confirms it
    independently.
    """
    has reached: list = [];

    can from_source with Source entry {
        self.reached.append(here.name);
        visit [edge ->:Pipe:closed == False:->];
        visit [edge <-:Pipe:closed == False:<-];
    }

    can spread with Junction entry {
        # 'skip' aborts this node only; 'disengage' would kill the whole
        # walker the first time the flood loops back on itself.
        if here.name in self.reached { skip; }
        self.reached.append(here.name);
        visit [edge ->:Pipe:closed == False:->];
        visit [edge <-:Pipe:closed == False:<-];
    }
}

walker ScreenIsolation {
    """Screens a repair isolation plan for modeled service impact.

    Two independent methods, deliberately. A walker floods the graph from the supply
    through pipe edges that are still open, so whatever it cannot reach has lost
    service by pure topology. Then the pressure-dependent hydraulic model is run on the
    same valve configuration. If the two disagree, something is wrong and we want to see
    it rather than trust one of them.
    """
    has leak: str;
    has use_backup: bool = False;
    has name: str = "";
    has critical_psi: float = 0.0;
    has baseline_psi: float = 0.0;
    has stranded_by_graph: list = [];
    has out_by_hydraulics: int = 0;
    has agree: bool = False;
    has accepted: bool = False;
    has nonphysical: int = 0;
    has pressure_only: list = [];   # lost service without being disconnected
    has already_dry: list = [];     # cut off, but had no service to lose
    has segment: list = [];
    has override_segment: list = [];   # when set, screen this valve set instead

    can screen with entry {
        juncs = of_type([-->], Junction);
        target = None;
        for j in juncs { if j.name == self.leak { target = j; } }
        supply = of_type([-->], Source)[0];

        # Default plan is the tightest one: close every valve touching the break.
        # A search can hand us any other valve set through override_segment.
        self.segment = [];
        if len(self.override_segment) > 0 {
            self.segment = self.override_segment;
            for e in all_pipes(juncs) {
                if e.pid in self.segment { e.closed = True; }
            }
        } else {
            for e in [edge target ->:Pipe:->] { e.closed = True; self.segment.append(e.pid); }
            for e in [edge target <-:Pipe:<-] { e.closed = True; self.segment.append(e.pid); }
        }

        # If the plan opens the emergency interconnect, that main is a real edge and
        # the graph has to see it. Otherwise the walker reports customers stranded who
        # are in fact being fed from the backup, and the cross-check is meaningless.
        backup = None;
        tie = None;
        if self.use_backup {
            for j in juncs { if j.name == INTERCONNECT_FROM { tie = j; } }
            backup = Source(name="BACKUP");
            here ++> backup;
            backup +>:Pipe(pid="BACKUP_MAIN"):+> tie;
        }

        # method 1 — graph reachability
        flood = supply spawn FloodFromSource();
        if backup != None {
            bflood = backup spawn FloodFromSource();
            for n in bflood.reached {
                if n not in flood.reached { flood.reached.append(n); }
            }
        }
        for j in juncs {
            # the break node is stranded too - it is the one being isolated for repair.
            # Both methods must count it, or the cross-check is off by one and the
            # agreement claim is quietly false.
            if j.name not in flood.reached { self.stranded_by_graph.append(j.name); }
        }

        # method 2 — pressure-dependent hydraulics on the same valve configuration
        base = snapshot(INP, pdd=True, service_min_psi=SERVICE_MIN_PSI);
        ic = None;
        if self.use_backup { ic = INTERCONNECT_FROM; }
        after = snapshot(INP, pdd=True, service_min_psi=SERVICE_MIN_PSI,
                         closed_pipes=self.segment, interconnect_from=ic,
                         interconnect_head_m=INTERCONNECT_HEAD);

        # A node is out of service if pressure fell below the service floor, OR if the
        # solver returned a non-physical value. The second case is not pedantry: closing
        # valves can disconnect a subnetwork, EPANET then reports millions of psi instead
        # of failing, and reading that as "above 20 psi, fine" told us 0 customers were
        # affected when 12 had been cut off. The graph walker caught it.
        lost = [];
        self.nonphysical = 0;
        for j in NODES {
            bad = after[j] > NONPHYSICAL_PSI or after[j] != after[j];   # NaN never equals itself
            if bad { self.nonphysical += 1; }
            if (bad or after[j] < SERVICE_MIN_PSI) and base[j] >= SERVICE_MIN_PSI {
                lost.append(j);
            }
        }
        self.out_by_hydraulics = len(lost);
        self.critical_psi = after[CRITICAL_NODE];
        self.baseline_psi = base[CRITICAL_NODE];
        # a solver artifact at the critical facility must never read as "plenty of
        # pressure" — that would accept a plan that strands a hospital
        if self.critical_psi > NONPHYSICAL_PSI or self.critical_psi != self.critical_psi {
            self.critical_psi = 0.0;
        }
        self.accepted = self.critical_psi >= CRITICAL_MIN_PSI;
        # The two methods answer different questions and the difference is the point.
        # Topology reports who is CUT OFF. Hydraulics reports who is BELOW SERVICE
        # PRESSURE. Closing valves can starve a junction that is still connected, and
        # only the hydraulic run can see that. Where they differ, record which nodes and
        # why, rather than reporting a bare disagreement.
        for j in lost {
            if j not in self.stranded_by_graph { self.pressure_only.append(j); }
        }
        for j in self.stranded_by_graph {
            if j not in lost { self.already_dry.append(j); }
        }
        self.agree = sorted(self.stranded_by_graph) == sorted(lost);

        # reopen so the graph is clean for the next plan
        for e in all_pipes(juncs) { e.closed = False; }
        if backup != None { del backup; }

        verdict = "REJECTED";
        if self.accepted { verdict = "ACCEPTED"; }
        extra = "";
        if len(self.pressure_only) > 0 {
            extra += f"; {len(self.pressure_only)} starved while still connected";
        }
        if len(self.already_dry) > 0 {
            extra += f"; {len(self.already_dry)} cut off but already below service "
                     f"pressure before the work";
        }
        here ++> Finding(kind="isolation", verdict=verdict,
                         detail=f"{self.name}: critical facility {self.baseline_psi:.2f} "
                                f"-> {self.critical_psi:.2f} psi, "
                                f"{self.out_by_hydraulics} junctions out of service{extra}");
    }
}


def all_pipes(juncs: list) -> list {
    """Every Pipe edge in the graph, once. Each edge is listed by its source node, and
    sources feed junctions, so walking outgoing edges from both node kinds covers all
    of them without duplicates.""";
    out = [];
    for n in juncs { for e in [edge n ->:Pipe:->] { out.append(e); } }
    for n in of_type([root-->], Source) { for e in [edge n ->:Pipe:->] { out.append(e); } }
    return out;
}


walker ValveRings {
    """Grows outward from the break and reports the valves at each ring.

    A crew cannot always close the valves either side of a break: one may be buried,
    seized, or missing from the map. The next option is to close a wider ring. Which
    valves form that ring is a question about the graph, so a walker answers it.
    """
    has depth: int = 2;
    has rings: list = [];

    can grow with Junction entry {
        frontier = [here];
        seen = [here.name];
        d = 0;
        while d < self.depth {
            pids = [];
            nxt = [];
            for n in frontier {
                for (e, nb) in zip([edge n ->:Pipe:->], [n ->:Pipe:->]) {
                    if e.pid not in pids { pids.append(e.pid); }
                    if isinstance(nb, Junction) and nb.name not in seen {
                        seen.append(nb.name); nxt.append(nb);
                    }
                }
                for (e, nb) in zip([edge n <-:Pipe:<-], [n <-:Pipe:<-]) {
                    if e.pid not in pids { pids.append(e.pid); }
                    if isinstance(nb, Junction) and nb.name not in seen {
                        seen.append(nb.name); nxt.append(nb);
                    }
                }
            }
            self.rings.append(pids);
            frontier = nxt;
            d += 1;
        }
    }
}


walker SearchIsolation {
    """Searches valve configurations instead of assuming one.

    Enumerates the tight ring and the wider ring, each with and without the emergency
    interconnect, screens every one, and ranks them: plans that hold the critical
    facility first, then fewest customers stranded, then fewest valves turned.
    """
    has leak: str;
    has considered: list = [];
    has best: dict = {};

    can search with entry {
        juncs = of_type([-->], Junction);
        target = None;
        for j in juncs { if j.name == self.leak { target = j; } }
        rings = (target spawn ValveRings(depth=2)).rings;

        plans = [];
        labels = ["tight ring", "wider ring"];
        for (i, pids) in enumerate(rings) {
            for backup in [False, True] {
                nm = labels[i];
                if backup { nm = nm + " + backup supply"; }
                plans.append([nm, pids, backup]);
            }
        }

        scored = [];
        for pl in plans {
            r = root spawn ScreenIsolation(leak=self.leak, name=pl[0],
                                           use_backup=pl[2], override_segment=pl[1]);
            row = {"name": pl[0], "valves": len(pl[1]), "segment": pl[1],
                   "backup": pl[2], "critical_psi": r.critical_psi,
                   "baseline_psi": r.baseline_psi, "out": r.out_by_hydraulics,
                   "stranded_graph": r.stranded_by_graph,
                   "pressure_only": r.pressure_only,
                   "already_dry": r.already_dry,
                   "agree": r.agree, "accepted": r.accepted};
            self.considered.append(row);
            # rank key: holds the hospital, then fewest customers out, then fewest valves
            hold = 0;
            if not r.accepted { hold = 1; }
            scored.append([hold, r.out_by_hydraulics, len(pl[1]), len(scored)]);
        }
        scored.sort();
        self.best = self.considered[scored[0][3]];
    }
}


walker PlanForCandidates {
    """Isolation plans for every candidate the evidence still supports.

    This exists because of a measured result, not a hunch. The exact junction is
    identified about 10% of the time, so screening only the leading candidate plans for
    a location that is usually wrong. A crew about to shut water off needs to know which
    of the plausible break sites has a safe isolation and which does not — and if any of
    them would strand the hospital, that is worth knowing before the truck moves.
    """
    has top_n: int = 3;
    has plans: list = [];
    has dangerous: list = [];

    can plan with entry {
        hyps = of_type([-->], Hypothesis);
        ranked = [];
        for h in hyps { ranked.append([h.prob, h.location]); }
        ranked.sort(reverse=True);

        i = 0;
        while i < self.top_n and i < len(ranked) {
            loc = ranked[i][1];
            s = root spawn SearchIsolation(leak=loc);
            best = s.best;
            worst_psi = 1e9;
            for c in s.considered {
                if c["critical_psi"] < worst_psi { worst_psi = c["critical_psi"]; }
            }
            row = {"candidate": loc, "probability": ranked[i][0],
                   "best_plan": best["name"], "valves": best["valves"],
                   "critical_psi": best["critical_psi"], "out": best["out"],
                   "naive_critical_psi": worst_psi,
                   "safe": best["accepted"], "considered": s.considered};
            self.plans.append(row);
            # the finding a foreman actually needs: is there a way to get this wrong?
            if worst_psi < CRITICAL_MIN_PSI { self.dangerous.append(loc); }
            i += 1;
        }
    }
}
