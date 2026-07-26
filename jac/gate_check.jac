include graphops;

with entry {
    for n in [root-->] { del n; }
    root spawn IngestNetwork();
    root spawn BuildForwardModel();
    tot = 0.0; cle = 0.0; k = 0; sizes = [];
    for (i, t) in enumerate(NODES) {
        si = root spawn StageIncident(truth=t, seed=1000 + i);
        sizes.append(si.true_leak_c / LEAK_C);
        g = root spawn CheckNonCircularity(truth=t);
        tot += g.median; cle += g.cleared; k += 1;
    }
    sizes.sort();
    print(f"\nincidents            {k}");
    print(f"median divergence    {tot/k:.3f} psi   (gauge noise {GAUGE_NOISE} psi)");
    print(f"gauges clearing floor {100.0*cle/k:.0f}%");
    print(f"leak size vs assumed  x{sizes[0]:.2f} .. x{sizes[-1]:.2f}, median x{sizes[k//2]:.2f}");
    if tot/k > GAUGE_NOISE { print("GATE PASSES: evidence departs from the nominal model by more than gauge noise"); }
    else { print("GATE FAILS: perturbation still cancels"); }
}
