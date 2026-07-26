import from hydraulics { topology, run }

with entry {
    t = topology();
    print("junctions", len(t["junctions"]), "gauges", len(t["gauges"]));
    b = run();
    print("baseline gauge count", len(b));
}
