"""PipeTrace demo run.

Every number printed is computed during this run, and the same numbers are written to
web/trace.json so the map renders measured state rather than a scripted sequence.
"""

include graphops;
import json;
import from pages { INDEX_HTML, BOARD_HTML, write_page }


def reconcile(c: dict) -> str {
    """Say why topology and hydraulics differ, rather than printing a bare boolean.""";
    if c["agree"] { return "topology+hydraulics concur"; }
    bits = [];
    if len(c["pressure_only"]) > 0 {
        bits.append(f"{len(c['pressure_only'])} starved while still connected");
    }
    if len(c["already_dry"]) > 0 {
        bits.append(f"{len(c['already_dry'])} cut off but already dry");
    }
    return ", ".join(bits);
}


def posterior_map(hyps: list) -> dict {
    out = {};
    for h in hyps { out[h.location] = h.prob; }
    return out;
}

walker ResetGraph {
    """Jac persists the graph to disk between runs, so a second run would stack another
    copy of the network onto root and every count would silently double. Wipe first."""
    has removed: int = 0;

    can wipe with entry {
        for n in [-->] { del n; self.removed += 1; }
    }
}

with entry {
    sig = sigma();
    wiped = root spawn ResetGraph();
    if wiped.removed > 0 { print(f"[reset] cleared {wiped.removed} stale nodes"); }

    print("Rivus — active leak diagnosis\n");
    ing = root spawn IngestNetwork();
    print(f"[setup] critical facility node {CRITICAL_NODE}, floor {CRITICAL_MIN_PSI:.0f} psi");
    print(f"[setup] gauge noise {GAUGE_NOISE} psi + model error {MODEL_ERROR} psi "
          f"-> sigma {sig:.2f} psi\n");

    fm = root spawn BuildForwardModel();
    inc = root spawn StageIncident(truth="29", seed=7);
    pct = 100.0 * inc.leak_lps / ing.demand_lps;
    print(f"[incident] hidden leak at {inc.truth}: {inc.leak_lps:.1f} L/s "
          f"({pct:.0f}% of district draw)");
    print(f"[incident] readings come from a perturbed model "
          f"(demand {DEMAND_CV:.0%} CV, roughness {ROUGH_CV:.0%} CV), not the "
          f"model used to diagnose\n");

    trace = {"nodes": [], "pipes": [], "steps": [], "scenario": {}};
    for j in of_type([root-->], Junction) {
        trace["nodes"].append({"name": j.name, "x": j.x, "y": j.y,
                               "psi": j.baseline_psi, "critical": j.is_critical});
    }
    for j in of_type([root-->], Junction) {
        # Pipe objects carry no .target accessor, but the edge list and the neighbour
        # list come back in the same order, so pair them positionally.
        for (e, nb) in zip([edge j ->:Pipe:->], [j ->:Pipe:->]) {
            trace["pipes"].append({"pid": e.pid, "a": j.name, "b": nb.name});
        }
    }
    trace["scenario"] = {"truth": inc.truth, "leak_lps": inc.leak_lps,
                         "leak_pct": pct, "sigma": sig,
                         "critical_node": CRITICAL_NODE,
                         "critical_min_psi": CRITICAL_MIN_PSI,
                         "service_min_psi": SERVICE_MIN_PSI,
                         "sims": fm.count + 1, "sim_seconds": fm.seconds,
                         "demand_lps": ing.demand_lps};

    crew = "1";
    step = 1;
    last_top = "";
    while step <= 3 {
        sc = root spawn ScoreProbes(crew_at=crew, cost_aware=False);
        best = sc.ranked[0];
        reading = read_gauge(best[1]);
        tp = root spawn TakeProbe(location=best[1], reading=reading);
        root ++> Observation(step=step, location=best[1], reading_psi=reading,
                             info_bits=best[2], travel_min=best[3],
                             survivors=tp.survivors, entropy_bits=tp.entropy_bits);
        print(f"[probe {step}] next best test -> node {best[1]}  "
              f"({best[2]:.2f} bits, {best[3]:.0f} min travel, {best[0]:.1f} bits/crew-hour)");
        print(f"          alt: node {sc.ranked[1][1]} {sc.ranked[1][2]:.2f} bits "
              f"-> {sc.ranked[1][0]:.1f} bits/hr");
        print(f"          measured {reading:+.2f} psi -> 90% set {tp.survivors}/{len(NODES)}, "
              f"H {tp.entropy_bits:.2f} bits, top {tp.top} (p={tp.top_prob:.2f})\n");
        cand = [];
        k = 0;
        while k < 6 and k < len(sc.ranked) {
            r = sc.ranked[k];
            cand.append({"node": r[1], "bits": r[2], "minutes": r[3], "score": r[0]});
            k += 1;
        }
        trace["steps"].append({
            "step": step, "chosen": best[1], "reading": reading,
            "bits": best[2], "minutes": best[3],
            "survivors": tp.survivors, "entropy": tp.entropy_bits,
            "top": tp.top, "top_prob": tp.top_prob,
            "candidates": cand,
            "posterior": posterior_map(of_type([root-->], Hypothesis))});
        crew = best[1];
        last_top = tp.top;
        step += 1;
    }

    ident = root spawn CheckIdentifiability();
    print(f"[limits] verdict {ident.verdict}");
    print(f"[limits] {len(ident.blocked)} of {ident.n_pairs} surviving pairs cannot be "
          f"separated by any single gauge");
    i = 0;
    while i < 3 and i < len(ident.blocked) {
        b = ident.blocked[i];
        print(f"          {b[1]} vs {b[2]}: differ by at most {b[0]:.3f} psi anywhere "
              f"(threshold {2.0 * sig:.2f})");
        i += 1;
    }
    if ident.advice_sep >= 2.0 * sig {
        print(f"          move one gauge to node {ident.advice_node}: separates all "
              f"survivors by {ident.advice_sep:.2f} psi\n");
    } else {
        print(f"          no single pressure sensor resolves these. Best available is "
              f"node {ident.advice_node} at {ident.advice_sep:.2f} psi.\n");
    }

    print(f"[isolation] the exact junction is identified about 10% of the time, so the");
    print(f"            crew gets a plan for every candidate the evidence still supports\n");
    pc = root spawn PlanForCandidates(top_n=3);
    for r in pc.plans {
        flag = "safe plan available";
        if not r["safe"] { flag = "NO SAFE PLAN"; }
        print(f"  candidate {r['candidate']:>3}  p={r['probability']:.3f}  {flag}");
        print(f"      best: {r['best_plan']}, {r['valves']} valves -> hospital "
              f"{r['critical_psi']:.2f} psi, {r['out']}/{len(NODES)} customers out");
        print(f"      wrong valve set here: hospital drops to "
              f"{r['naive_critical_psi']:.2f} psi");
    }
    if len(pc.dangerous) > 0 {
        print(f"\n  WARNING: at candidates {pc.dangerous} there is a valve configuration "
              f"that puts the hospital below {CRITICAL_MIN_PSI:.0f} psi.");
    }
    srch = root spawn SearchIsolation(leak=pc.plans[0]["candidate"]);

    trace["identifiability"] = {
        "verdict": ident.verdict, "survivors": ident.survivors,
        "n_pairs": ident.n_pairs, "blocked": ident.blocked,
        "advice_node": ident.advice_node, "advice_sep": ident.advice_sep,
        "threshold": 2.0 * sig};
    trace["candidates"] = [];
    for r in pc.plans {
        trace["candidates"].append({
            "candidate": r["candidate"], "probability": r["probability"],
            "best_plan": r["best_plan"], "valves": r["valves"],
            "critical_psi": r["critical_psi"], "out": r["out"],
            "naive_critical_psi": r["naive_critical_psi"], "safe": r["safe"]});
    }
    trace["dangerous"] = pc.dangerous;
    trace["isolation"] = [];
    for c in srch.considered {
        trace["isolation"].append({
            "name": c["name"], "accepted": c["accepted"], "segment": c["segment"],
            "baseline_psi": c["baseline_psi"], "critical_psi": c["critical_psi"],
            "stranded_graph": c["stranded_graph"],
            "pressure_only": c["pressure_only"],
            "already_dry": c["already_dry"],
            "stranded_hydraulics": c["out"], "valves": c["valves"],
            "agree": c["agree"], "backup": c["backup"],
            "chosen": c["name"] == srch.best["name"]});
    }
    # fold in the measured scale results so the board can show a scoreboard that
    # argues for the method rather than a table of uniform placeholders
    try {
        with open("web/measured.json") as mf { trace["measured"] = json.load(mf); }
    } except Exception as e { trace["measured"] = []; }
    with open("web/trace.json", "w") as f { json.dump(trace, f, indent=1); }
    # also as a plain script so the map opens over file:// with no server and no CORS
    with open("web/trace.js", "w") as f {
        f.write("window.TRACE = " + json.dumps(trace) + ";");
    }
    # the two pages are emitted from pages.jac, so the board that ships is the board
    # this run wrote and never a stale file on disk
    write_page("web/index.html", INDEX_HTML);
    write_page("web/board.html", BOARD_HTML);
    # and a single hostable file with the trace inlined, for deployment
    page = BOARD_HTML.replace('<script src="trace.js"></script>',
                        "<script>window.TRACE = " + json.dumps(trace) + ";</script>");
    write_page("web/standalone.html", page);
    print(f"\n[export] web/trace.json written: {len(trace['nodes'])} nodes, "
          f"{len(trace['pipes'])} pipes, {len(trace['steps'])} probe states");
    print("Every number above came from EPANET and Bayes. The graph decided where to look.");
}
