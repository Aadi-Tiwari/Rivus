include graphops;

with entry {
    for n in [root-->] { del n; }
    root spawn IngestNetwork();
    juncs = of_type([root-->], Junction);
    tgt = None;
    for j in juncs { if j.name == "12" { tgt = j; } }
    rings = (tgt spawn ValveRings(depth=2)).rings;
    print("tight ring pipes:", rings[0]);
    base = snapshot(INP, pdd=True, service_min_psi=SERVICE_MIN_PSI);
    after = snapshot(INP, pdd=True, service_min_psi=SERVICE_MIN_PSI, closed_pipes=rings[0]);
    print("\nhydraulics after closing the tight ring:");
    for j in ["1","2","5","9","10","11","12","13","20"] {
        print(f"   node {j}: {base[j]:6.2f} -> {after[j]:6.2f} psi");
    }
    print(f"\nsupply source node: {META}");
    src = of_type([root-->], Source)[0];
    print("source name:", src.name);
    print("source pipe neighbours:", [x.name for x in [src ->:Pipe:->]] + [x.name for x in [src <-:Pipe:<-]]);
}
