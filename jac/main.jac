include pipetrace;

with entry {
    SIGMA = sigma();
    print(f"sigma = {SIGMA:.3f} psi");
    ing = root spawn IngestNetwork();
    print("junctions on graph:", len(of_type([root-->], Junction)));
}
