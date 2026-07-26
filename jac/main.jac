"""PipeTrace demo run.

Every number printed is computed during this run, and the same numbers are written to
web/trace.json so the map renders measured state rather than a scripted sequence.
"""

include diagnose;
import json;


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

    print("PipeTrace — active leak diagnosis\n");
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

    print(f"[isolation] screening repair plans for leading candidate {last_top}");
    a = root spawn ScreenIsolation(leak=last_top, name="close repair segment");
    b = root spawn ScreenIsolation(leak=last_top, use_backup=True,
                                   name="backup supply, then close");
    for r in [a, b] {
        v = "REJECTED";
        if r.accepted { v = "ACCEPTED"; }
        print(f"  {v:<9} {r.name}");
        print(f"            closes {r.segment}");
        print(f"            critical facility {CRITICAL_NODE}: {r.baseline_psi:.2f} "
              f"-> {r.critical_psi:.2f} psi   |   {r.out_by_hydraulics}/{len(NODES)} "
              f"junctions below {SERVICE_MIN_PSI:.0f} psi");
        print(f"            graph walker stranded {len(r.stranded_by_graph)}, "
              f"hydraulics stranded {r.out_by_hydraulics}, agree={r.agree}");
    }
    trace["identifiability"] = {
        "verdict": ident.verdict, "survivors": ident.survivors,
        "n_pairs": ident.n_pairs, "blocked": ident.blocked,
        "advice_node": ident.advice_node, "advice_sep": ident.advice_sep,
        "threshold": 2.0 * sig};
    trace["isolation"] = [];
    for r in [a, b] {
        trace["isolation"].append({
            "name": r.name, "accepted": r.accepted, "segment": r.segment,
            "baseline_psi": r.baseline_psi, "critical_psi": r.critical_psi,
            "stranded_graph": r.stranded_by_graph,
            "stranded_hydraulics": r.out_by_hydraulics,
            "agree": r.agree, "backup": r.use_backup});
    }
    with open("web/trace.json", "w") as f { json.dump(trace, f, indent=1); }
    # also as a plain script so the map opens over file:// with no server and no CORS
    with open("web/trace.js", "w") as f {
        f.write("window.TRACE = " + json.dumps(trace) + ";");
    }
    print(f"\n[export] web/trace.json written: {len(trace['nodes'])} nodes, "
          f"{len(trace['pipes'])} pipes, {len(trace['steps'])} probe states");
    print("Every number above came from EPANET and Bayes. The graph decided where to look.");
}
