"""PipeTrace as a service.

Exposes the investigation over REST so the incident board can be hosted rather than
opened from disk. The walkers here are the same ones the CLI runs — nothing is
reimplemented for the web, and no number is computed differently.

    jac start jac/serve.jac --port 8080
"""

include graphops;
include intake;

import json;


glob STATE: dict = {"trace": {}, "built": False};


def build_trace(truth: str, seed: int, probes: int) -> dict {
    """Run one full investigation and return everything the board needs.""";
    for n in [root-->] { del n; }
    ing = root spawn IngestNetwork();
    fm = root spawn BuildForwardModel();
    inc = root spawn StageIncident(truth=truth, seed=seed);

    trace = {"nodes": [], "pipes": [], "steps": [], "scenario": {}, "isolation": []};
    juncs = of_type([root-->], Junction);
    for j in juncs {
        trace["nodes"].append({"name": j.name, "x": j.x, "y": j.y,
                               "psi": j.baseline_psi, "critical": j.is_critical});
    }
    for j in juncs {
        for (e, nb) in zip([edge j ->:Pipe:->], [j ->:Pipe:->]) {
            trace["pipes"].append({"pid": e.pid, "a": j.name, "b": nb.name});
        }
    }
    trace["scenario"] = {
        "truth": inc.truth, "leak_lps": inc.leak_lps,
        "leak_pct": 100.0 * inc.leak_lps / ing.demand_lps, "sigma": sigma(),
        "critical_node": CRITICAL_NODE, "critical_min_psi": CRITICAL_MIN_PSI,
        "service_min_psi": SERVICE_MIN_PSI, "sims": fm.count + 1,
        "sim_seconds": fm.seconds, "demand_lps": ing.demand_lps};

    crew = "1";
    step = 1;
    top = "";
    while step <= probes {
        sc = root spawn ScoreProbes(crew_at=crew, cost_aware=False);
        best = sc.ranked[0];
        reading = read_gauge(best[1]);
        tp = root spawn TakeProbe(location=best[1], reading=reading);
        cand = [];
        k = 0;
        while k < 6 and k < len(sc.ranked) {
            r = sc.ranked[k];
            cand.append({"node": r[1], "bits": r[2], "minutes": r[3], "score": r[0]});
            k += 1;
        }
        post = {};
        for h in of_type([root-->], Hypothesis) { post[h.location] = h.prob; }
        trace["steps"].append({
            "step": step, "chosen": best[1], "reading": reading,
            "bits": best[2], "minutes": best[3], "survivors": tp.survivors,
            "entropy": tp.entropy_bits, "top": tp.top, "top_prob": tp.top_prob,
            "candidates": cand, "posterior": post});
        crew = best[1];
        top = tp.top;
        step += 1;
    }

    ident = root spawn CheckIdentifiability();
    trace["identifiability"] = {
        "verdict": ident.verdict, "survivors": ident.survivors,
        "n_pairs": ident.n_pairs, "blocked": ident.blocked,
        "advice_node": ident.advice_node, "advice_sep": ident.advice_sep,
        "threshold": 2.0 * sigma()};

    srch = root spawn SearchIsolation(leak=top);
    for c in srch.considered {
        trace["isolation"].append({
            "name": c["name"], "accepted": c["accepted"], "segment": c["segment"],
            "baseline_psi": c["baseline_psi"], "critical_psi": c["critical_psi"],
            "stranded_graph": c["stranded_graph"], "stranded_hydraulics": c["out"],
            "valves": c["valves"], "agree": c["agree"], "backup": c["backup"],
            "chosen": c["name"] == srch.best["name"]});
    }
    return trace;
}


walker investigate {
    """POST /walker/investigate — run a full investigation and return the trace.

    Hides a leak at `truth`, probes `probes` times, reports what pressure cannot
    resolve, and searches valve configurations. Every number is computed on this call.
    """
    has truth: str = "29";
    has seed: int = 7;
    has probes: int = 3;

    can run with entry {
        STATE["trace"] = build_trace(self.truth, self.seed, self.probes);
        STATE["built"] = True;
        report STATE["trace"];
    }
    class __specs__ {
        has auth: bool = False;
    }

}


walker trace {
    """GET the most recent investigation, running one first if none exists."""
    can fetch with entry {
        if not STATE["built"] { STATE["trace"] = build_trace("29", 7, 3); STATE["built"] = True; }
        report STATE["trace"];
    }
    class __specs__ {
        has auth: bool = False;
    }

}


walker parse_note {
    """POST /walker/parse_note — turn a crew's radio note into typed fields.

    The only endpoint backed by a language model, and it still decides nothing: it
    returns a typed reading, or refuses.
    """
    has note: str = "";

    can run with entry {
        if not STATE["built"] { STATE["trace"] = build_trace("29", 7, 3); STATE["built"] = True; }
        w = root spawn IngestNote(note=self.note);
        report {"accepted": w.accepted, "reason": w.reason,
                "location": w.parsed.location, "reading_psi": w.parsed.reading_psi,
                "has_reading": w.parsed.has_reading, "issue": w.parsed.issue,
                "confidence": w.parsed.confidence};
    }
    class __specs__ {
        has auth: bool = False;
    }

}


walker health {
    can ping with entry {
        report {"ok": True, "network": INP, "junctions": len(NODES)};
    }
    class __specs__ {
        has auth: bool = False;
    }

}
