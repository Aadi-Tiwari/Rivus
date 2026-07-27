"""Field-intake demo. Kept separate so `include intake;` stays side-effect free —
an entry block in a library file runs on every import and pollutes anything that
includes it, including the test suite.
"""

include intake;


with entry {
    for n in [root-->] { del n; }
    root spawn IngestNetwork();

    notes = [
        "hydrant by the school at 30 reads 41 psi, valve V7 is seized",
        "node 12 down to 38.5 PSI, main looks fine",
        "crew at 27, gauge is buried, no reading",
        "pressure feels low round the depot"
    ];

    print("\nPipeTrace field intake — the only place a language model runs\n");
    for n in notes {
        w = root spawn IngestNote(note=n);
        p = w.parsed;
        mark = "REJECTED";
        if w.accepted { mark = "ACCEPTED"; }
        print(f"  \"{n}\"");
        print(f"    -> {mark}: node={p.location or '?'} "
              f"reading={p.reading_psi if p.has_reading else 'none'} "
              f"issue={p.issue or 'none'} conf={p.confidence:.2f}");
        print(f"       {w.reason}\n");
    }
    obs = of_type([root-->], Observation);
    print(f"{len(obs)} observations typed onto the graph from {len(notes)} notes.");
    print("Everything downstream of here is EPANET and Bayes. The model reads; it "
          "does not decide.");
}
