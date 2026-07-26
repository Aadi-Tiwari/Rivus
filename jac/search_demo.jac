include graphops;

with entry {
    for n in [root-->] { del n; }
    root spawn IngestNetwork();
    root spawn BuildForwardModel();
    root spawn StageIncident(truth="29", seed=7);
    s = root spawn SearchIsolation(leak="27");
    print(f"\nsearched {len(s.considered)} valve configurations for a break at 27:\n");
    for c in s.considered {
        v = "REJECTED";
        if c["accepted"] { v = "ACCEPTED"; }
        print(f"  {v:<9} {c['name']:<28} {c['valves']} valves  "
              f"hospital {c['baseline_psi']:.2f} -> {c['critical_psi']:.2f} psi  "
              f"{c['out']} out  graph/hydraulics agree={c['agree']}");
    }
    print(f"\nchosen: {s.best['name']} — {s.best['valves']} valves, hospital "
          f"{s.best['critical_psi']:.2f} psi, {s.best['out']} customers out");
}
