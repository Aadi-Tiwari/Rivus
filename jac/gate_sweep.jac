include graphops;

glob CVS: list = [0.08, 0.15, 0.25, 0.35];

with entry {
    for n in [root-->] { del n; }
    root spawn IngestNetwork();
    root spawn BuildForwardModel();
    print(f"\ndaily demand variation vs evidence quality  (gauge noise {GAUGE_NOISE} psi)\n");
    print("  demand CV | median mismatch | vs signal | gauges clearing");
    for cv in CVS {
        tot = 0.0; cle = 0.0; sig = 0.0; k = 0;
        for (i, t) in enumerate(NODES) {
            root spawn StageIncident(truth=t, seed=1000 + i, demand_cv=cv);
            g = root spawn CheckNonCircularity(truth=t);
            # how big is the true signal we are trying to read?
            mags = [];
            for j in NODES { mags.append(abs(OBSERVED[j])); }
            mags.sort();
            sig += mags[len(mags) - 1];
            tot += g.median; cle += g.cleared; k += 1;
        }
        print(f"     {cv:.2f}   |    {tot/k:.3f} psi    |   {100.0*(tot/k)/(sig/k):.0f}%   |   {100.0*cle/k:.0f}%");
    }
}
