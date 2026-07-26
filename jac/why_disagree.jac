include graphops;

with entry {
    for n in [root-->] { del n; }
    root spawn IngestNetwork();
    root spawn BuildForwardModel();
    root spawn StageIncident(truth="29", seed=7);
    s = root spawn SearchIsolation(leak="12");
    for c in s.considered {
        print(f"{c['name']:<30} valves={c['valves']} graph_stranded={len(c['stranded_graph'])} "
              f"hydraulics_out={c['out']} agree={c['agree']}");
        print(f"    graph says: {sorted(c['stranded_graph'])}");
    }
    print("\n-- who does hydraulics drop below service, for the wider ring? --");
    juncs = of_type([root-->], Junction);
    tgt = None;
    for j in juncs { if j.name == "12" { tgt = j; } }
    rings = (tgt spawn ValveRings(depth=2)).rings;
    base = snapshot(INP, pdd=True, service_min_psi=SERVICE_MIN_PSI);
    after = snapshot(INP, pdd=True, service_min_psi=SERVICE_MIN_PSI, closed_pipes=rings[1]);
    for j in NODES {
        if after[j] < SERVICE_MIN_PSI and base[j] >= SERVICE_MIN_PSI {
            print(f"    node {j}: {base[j]:.1f} -> {after[j]:.1f} psi");
        }
    }
}
