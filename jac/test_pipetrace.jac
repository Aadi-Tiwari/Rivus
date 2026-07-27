"""Tests that lock the physics and, more importantly, lock the honesty.

Several of these exist to fail loudly if someone later "improves" the project into
something that overclaims. That is deliberate. Run with:

    rm -rf .jac && PYTHONPATH=$PWD ./.venv/bin/jac run jac/test_pipetrace.jac

(`jac test` is unusable on jaclang 0.16.7 — it dies with "No bytecode found", the same
tooling rot that makes `jac check` report errors on files that run perfectly. So this is
a plain runner: every test is a def, and the entry block runs them and counts.)
"""

include graphops;
include intake;


glob READY: dict = {"built": False};


def expect(cond: bool) -> None {
    if not cond { raise AssertionError("check failed"); }
}


def setup_once() -> None {
    """Build the graph and forward model once and reuse it across tests.""";
    if READY["built"] { return; }
    for n in [root-->] { del n; }
    root spawn IngestNetwork();
    root spawn BuildForwardModel();
    READY["built"] = True;
}


# ----------------------------------------------------------------- hydraulics
def network_loads_as_a_graph() -> None {
    setup_once();
    expect(len(of_type([root-->], Junction)) == 35);
    expect(len(of_type([root-->], Source)) >= 1);
}

def every_pipe_became_an_edge() -> None {
    setup_once();
    juncs = of_type([root-->], Junction);
    expect(len(all_pipes(juncs)) == 40);
}

def district_demand_is_positive() -> None {
    # regression: Net2 carries a negative base demand at one node, and summing raw
    # values once made the district draw come out negative.
    setup_once();
    expect(topology(INP)["demand_lps"] > 0.0);
}

def a_leak_pulls_pressure_down_somewhere() -> None {
    setup_once();
    for h in of_type([root-->], Hypothesis) {
        expect(min(h.signature) < 0.0);
    }
}

def leak_is_a_material_fraction_of_demand() -> None {
    # If this drops far enough the signature sinks under the gauge noise floor and
    # localization stops working. The scenario must stay honest about being a break.
    setup_once();
    base = snapshot(INP);
    head = base[NODES[0]] / 1.4219702063247;
    lps = LEAK_C * math.sqrt(head) * 1000.0;
    expect(lps / topology(INP)["demand_lps"] > 0.15);
}


# ------------------------------------------------------------------ inference
def posterior_stays_a_distribution() -> None {
    setup_once();
    root spawn StageIncident(truth="29", seed=7);
    root spawn TakeProbe(location="5", reading=-0.4);
    total = 0.0;
    for h in of_type([root-->], Hypothesis) {
        expect(h.prob >= 0.0);
        total += h.prob;
    }
    expect(abs(total - 1.0) < 1e-9);
}

def a_contradicting_reading_falls_back_rather_than_nan() -> None {
    # Every hypothesis contradicted must return to the prior, not produce NaNs that
    # quietly poison the display.
    setup_once();
    root spawn StageIncident(truth="29", seed=7);
    root spawn TakeProbe(location="5", reading=1000000.0);
    total = 0.0;
    for h in of_type([root-->], Hypothesis) { total += h.prob; }
    expect(abs(total - 1.0) < 1e-9);
}

def probing_reduces_entropy() -> None {
    setup_once();
    root spawn StageIncident(truth="29", seed=7);
    for h in of_type([root-->], Hypothesis) {
        h.prob = 1.0 / len(of_type([root-->], Hypothesis));
    }
    before = math.log2(float(len(NODES)));
    tp = root spawn TakeProbe(location="3", reading=read_gauge("3"));
    expect(tp.entropy_bits < before);
}


# -------------------------------------------------------------- honesty guards
def evidence_is_not_the_forward_model_replayed() -> None {
    """The claim this protects: the diagnosis is not inverting its own simulator.

    The earlier version of this test compared absolute pressure fields and passed while
    the thing it claimed to protect was broken. The inference never sees absolute
    pressures — it sees RESIDUALS, and a perturbation applied to both snapshots cancels
    there. Person B caught it with a measurement. This checks residual space, which is
    what actually feeds the posterior.
    """;
    setup_once();
    total = 0.0;
    n = 0;
    for t in [NODES[3], NODES[12], NODES[24]] {
        root spawn StageIncident(truth=t, seed=4242 + n);
        sig = [];
        for h in of_type([root-->], Hypothesis) {
            if h.location == t { sig = h.signature; }
        }
        for (i, j) in enumerate(NODES) { total += abs(OBSERVED[j] - sig[i]); n += 1; }
    }
    mean_mismatch = total / n;
    # Not a gauge-noise bar: model mismatch smaller than gauge noise is normal and does
    # not imply circularity. The bar is that the evidence is materially different from
    # the model's own prediction rather than a replay of it.
    expect(mean_mismatch > 0.02);
}


def the_true_leak_size_is_unknown_to_the_diagnosis() -> None {
    """The forward model assumes LEAK_C. If the staged break were always exactly that
    size, one whole source of real model error would be missing.""";
    setup_once();
    sizes = [];
    for i in [0, 1, 2, 3, 4, 5] {
        si = root spawn StageIncident(truth=NODES[i], seed=900 + i);
        sizes.append(si.true_leak_c / LEAK_C);
    }
    spread = max(sizes) - min(sizes);
    expect(spread > 0.1);
}


def identifiability_reports_pairs_not_merged_clusters() -> None {
    """Indistinguishability is not transitive. An earlier version used union-find and
    chained the whole network into one meaningless blob.""";
    setup_once();
    root spawn StageIncident(truth="29", seed=7);
    ident = root spawn CheckIdentifiability();
    expect(len(ident.blocked) <= ident.n_pairs);
    for b in ident.blocked {
        expect(len(b) == 4);
        expect(b[0] < 2.0 * sigma());
        expect(b[1] != b[2]);        # never a junction against itself
    }
}


# -------------------------------------------------------------------- isolation
def the_naive_plan_is_rejected() -> None {
    setup_once();
    r = root spawn ScreenIsolation(leak="27", name="tight ring");
    expect(not r.accepted);
    expect(r.critical_psi < CRITICAL_MIN_PSI);
}

def the_backup_plan_is_accepted() -> None {
    setup_once();
    r = root spawn ScreenIsolation(leak="27", use_backup=True, name="with backup");
    expect(r.accepted);
    expect(r.critical_psi >= CRITICAL_MIN_PSI);
}

def restored_pressure_never_exceeds_baseline() -> None {
    """A plan that raises pressure above the undisturbed baseline would be a modelling
    artefact, and a judge would rightly ask why closing a pipe raised pressure.""";
    setup_once();
    r = root spawn ScreenIsolation(leak="27", use_backup=True, name="with backup");
    expect(r.critical_psi <= r.baseline_psi);
}

def both_methods_agree_on_every_searched_plan() -> None {
    """The graph walker and the hydraulic model share no code. If they ever disagree
    on who loses water, the cross-check claim in the README is false.""";
    setup_once();
    s = root spawn SearchIsolation(leak="27");
    expect(len(s.considered) >= 4);
    for c in s.considered { expect(c["agree"]); }
}

def the_search_picks_a_plan_that_holds_the_hospital() -> None {
    setup_once();
    s = root spawn SearchIsolation(leak="27");
    expect(s.best["accepted"]);
    expect(s.best["critical_psi"] >= CRITICAL_MIN_PSI);
}


# ----------------------------------------------------------------- field intake
def intake_refuses_a_note_with_no_reading() -> None {
    """Inventing a pressure reading would flow straight into the posterior. Intake must
    refuse rather than guess.""";
    setup_once();
    w = root spawn IngestNote(note="crew at 27, gauge is buried, no reading");
    expect(not w.accepted);
    expect(not w.parsed.has_reading);
}

def intake_does_not_read_a_node_id_out_of_a_decimal() -> None {
    """Regression: \\b5\\b matched the 5 inside '38.5 PSI', so 'node 12 ... 38.5 PSI'
    parsed as node 5 — a silently wrong reading, the worst kind.""";
    setup_once();
    w = root spawn IngestNote(note="node 12 down to 38.5 PSI, main looks fine");
    expect(w.parsed.location == "12");
    expect(abs(w.parsed.reading_psi - 38.5) < 1e-6);
}


with entry {
    cases = [
        ["network_loads_as_a_graph", network_loads_as_a_graph],
        ["every_pipe_became_an_edge", every_pipe_became_an_edge],
        ["district_demand_is_positive", district_demand_is_positive],
        ["a_leak_pulls_pressure_down_somewhere", a_leak_pulls_pressure_down_somewhere],
        ["leak_is_a_material_fraction_of_demand", leak_is_a_material_fraction_of_demand],
        ["posterior_stays_a_distribution", posterior_stays_a_distribution],
        ["a_contradicting_reading_falls_back_rather_than_nan", a_contradicting_reading_falls_back_rather_than_nan],
        ["probing_reduces_entropy", probing_reduces_entropy],
        ["evidence_is_not_the_forward_model_replayed", evidence_is_not_the_forward_model_replayed],
        ["the_true_leak_size_is_unknown_to_the_diagnosis", the_true_leak_size_is_unknown_to_the_diagnosis],
        ["identifiability_reports_pairs_not_merged_clusters", identifiability_reports_pairs_not_merged_clusters],
        ["the_naive_plan_is_rejected", the_naive_plan_is_rejected],
        ["the_backup_plan_is_accepted", the_backup_plan_is_accepted],
        ["restored_pressure_never_exceeds_baseline", restored_pressure_never_exceeds_baseline],
        ["both_methods_agree_on_every_searched_plan", both_methods_agree_on_every_searched_plan],
        ["the_search_picks_a_plan_that_holds_the_hospital", the_search_picks_a_plan_that_holds_the_hospital],
        ["intake_refuses_a_note_with_no_reading", intake_refuses_a_note_with_no_reading],
        ["intake_does_not_read_a_node_id_out_of_a_decimal", intake_does_not_read_a_node_id_out_of_a_decimal],
    ];
    passed = 0;
    failed = [];
    print("\nPipeTrace test suite\n");
    for c in cases {
        try {
            c[1]();
            passed += 1;
            print(f"  pass  {c[0]}");
        } except Exception as e {
            failed.append(c[0]);
            print(f"  FAIL  {c[0]}  ({e})");
        }
    }
    print(f"\n{passed}/{len(cases)} passed");
    if len(failed) > 0 { print(f"failed: {failed}"); }
}
