"""Export the real investigation in the shape the Next.js dashboard expects.

The dashboard was built against a hand-made fixture: 22 junctions, uniform posteriors,
and a summary table where random probing beat the method. All three were artifacts of
the fixture, not results. This runs the actual engine and writes the same schema, so the
page renders measured state and the FIXTURE badge can come off honestly.

    jac run jac/export_web.jac      ->  web/replay.json + web/replay.js
"""

include harness;

import json;
import from hydraulics { topology, flows }


glob ARMS: list = [
    ["randomControl", "random control", "random"],
    ["maxInfoGain", "max information gain", "info"],
    ["adaptive", "adaptive stopping", "adaptive"],
    ["allGauges", "all gauges", "all"]
];


walker TraceArm {
    """Runs one arm and records the per-step posterior the dashboard animates."""
    has truth: str;
    has arm: str;
    has budget: int = 3;
    has steps: list = [];
    has used: int = 0;
    has exact: bool = False;
    has top5: bool = False;

    can run with entry {
        root spawn ResetBelief();
        hyps = of_type([-->], Hypothesis);
        juncs = of_type([-->], Junction);

        # step 0 is the prior: no probe taken yet, which is why probeGauge is null
        self.steps.append(self.snap(hyps, None, None, None));

        crew = NODES[0];
        step = 0;
        while step < self.budget {
            chosen = "";
            bits = 0.0;
            if self.arm == "random" {
                pool = [];
                for j in juncs { if not j.measured { pool.append(j.name); } }
                chosen = pool[random.randrange(len(pool))];
            } else {
                sc = root spawn ScoreProbes(crew_at=crew,
                                            cost_aware=False, draws=EVAL_DRAWS);
                chosen = sc.ranked[0][1];
                bits = sc.ranked[0][2];
                if self.arm == "adaptive" and step > 0 and bits < STOP_BITS { break; }
            }
            reading = read_gauge(chosen);
            root spawn TakeProbe(location=chosen, reading=reading);
            self.steps.append(self.snap(hyps, chosen, reading, bits));
            crew = chosen;
            step += 1;
        }
        self.used = step;

        pairs = [];
        for h in of_type([-->], Hypothesis) { pairs.append([h.prob, h.location]); }
        pairs.sort(reverse=True);
        r = 1;
        for p in pairs {
            if p[1] == self.truth {
                self.exact = (r == 1);
                self.top5 = (r <= 5);
            }
            r += 1;
        }
    }

    def snap(hyps: list, gauge: any, reading: any, bits: any) -> dict {
        """One frame: the belief over every junction, its entropy, and the 90% set.""";
        post = {};
        ent = 0.0;
        for h in hyps {
            post[h.location] = round(h.prob, 5);
            if h.prob > 0.0 { ent += -h.prob * math.log2(h.prob); }
        }
        cs = credible_set(hyps, 0.90);
        out = {"probeGauge": gauge, "readingPsi": None, "eigBits": None,
               "posterior": post, "entropyBits": round(ent, 3), "credibleSet": cs};
        if reading != None { out["readingPsi"] = round(reading, 2); }
        if bits != None and bits > 0.0 { out["eigBits"] = round(bits, 3); }
        return out;
    }
}


with entry {
    for n in [root-->] { del n; }
    ing = root spawn IngestNetwork();
    root spawn BuildForwardModel();
    topo = topology(inp());

    net = {"junctions": [], "sources": [], "pipes": [], "gauges": []};
    for j in of_type([root-->], Junction) {
        net["junctions"].append({"id": j.name, "x": j.y, "y": -j.x});
        net["gauges"].append(j.name);      # our engine scores every junction
    }
    for s in of_type([root-->], Source) {
        c = topo["coords"][s.name];
        kind = "tank";
        if s.name in topo["sources"] and c[1] > 0.0 { kind = "tank"; }
        net["sources"].append({"id": s.name, "x": c[1], "y": -c[0], "kind": kind});
    }
    # Measured flow, not a placeholder: the board sets each pipe's dash speed from it,
    # so a main has to read faster than a branch.
    rate = flows(inp());
    for p in topo["pipes"] {
        net["pipes"].append({"id": p[0], "from": p[1], "to": p[2],
                             "flow": round(rate.get(p[0], 0.0), 2)});
    }

    # one incident, fully traced across all four arms
    truth = "29";
    root spawn StageIncident(truth=truth, seed=7);
    base = snapshot(inp());
    gpm = 0.0;
    arms = {};
    tally = {};
    for a in ARMS {
        budget = 3;
        if a[2] == "all" { budget = 8; }
        root spawn StageIncident(truth=truth, seed=7);
        t = root spawn TraceArm(truth=truth, arm=a[2], budget=budget);
        arms[a[0]] = {"steps": t.steps, "probesUsed": t.used,
                      "exactHit": t.exact, "top5Hit": t.top5};
        print(f"  {a[1]:<22} {t.used} probes, "
              f"{len(t.steps[-1]['credibleSet'])} still in play, "
              f"entropy {t.steps[-1]['entropyBits']:.2f} bits");
    }

    inc = [{"id": "INC-001", "trueLeakJunction": truth,
            "leakGpm": int(15.0 * 15.85), "arms": arms}];

    # summary from the measured sweep, not from this single incident
    meas = [];
    try {
        with open("web/measured.json") as mf { meas = json.load(mf); }
    } except Exception as e { meas = []; }
    # Two networks were swept. Keep them apart: the headline numbers have to describe the
    # network that is actually drawn, or the panel reads as one experiment when it is two.
    n2 = {};
    n3 = {};
    for m in meas {
        if m["junctions"] == len(NODES) { n2 = m; }
        if m["junctions"] > 50 { n3 = m; }
    }

    sm = {"nIncidents": 0, "chancePct": round(100.0 / len(NODES), 1),
          "noisePsi": GAUGE_NOISE, "arms": []};
    if len(n2) > 0 {
        # The arms quote this network. Quoting the 92-junction sweep beside a 35-junction
        # map and a 1-in-35 chance line put three different experiments in the same row,
        # and the incident count was hardcoded to 105, which matched neither sweep.
        sm["nIncidents"] = n2["incidents"];
        sm["arms"].append({"name": "random control", "key": "randomControl",
            "exactPct": round(n2["rand_top1"], 1), "top5Pct": round(n2["rand_top5"], 1),
            "meanHops": round(n2["rand_hops"], 2), "meanProbes": 3});
        sm["arms"].append({"name": "max information gain", "key": "maxInfoGain",
            "exactPct": round(n2["info_top1"], 1), "top5Pct": round(n2["info_top5"], 1),
            "meanHops": round(n2["info_hops"], 2), "meanProbes": 3});
        # Only the two arms actually measured in the sweep go in the summary. Adaptive
        # stopping and all-gauges are replayable above because their per-step traces are
        # real, but they were not swept, so a headline accuracy would be an invented number.
        sm["winner"] = "maxInfoGain";
        note = f"This network: {n2['junctions']} junctions, {n2['incidents']} incidents "
               f"per arm. Information gain lifts top-5 from {n2['rand_top5']:.1f}% to "
               f"{n2['info_top5']:.1f}% and ties the control on exact-junction accuracy "
               f"at {n2['info_top1']:.1f}%.";
        if len(n3) > 0 {
            note = note + f" On the larger {n3['junctions']}-junction district, "
                          f"{n3['incidents']} incidents per arm, it finds the exact junction "
                          f"{n3['info_top1']:.1f}% of the time against "
                          f"{n3['rand_top1']:.1f}% and lands {n3['lift']:.0f}% closer.";
        }
        sm["note"] = note;
    }

    out = {"fixture": False, "network": net, "incidents": inc, "summary": sm};
    with open("web/replay.json", "w") as f { json.dump(out, f); }
    # also as a plain script, so dashboard.html opens over file:// with no server
    with open("web/replay.js", "w") as f {
        f.write("window.REPLAY = " + json.dumps(out) + ";");
    }
    print(f"\n[export] web/replay.json — {len(net['junctions'])} junctions, "
          f"{len(net['pipes'])} pipes, {len(net['sources'])} sources, "
          f"{len(arms)} arms, fixture=False");
}
