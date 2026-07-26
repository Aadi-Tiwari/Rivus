"""Does using MORE gauges always help?

A teammate's build showed 8 gauges scoring below 3 random probes. That is either a
broken posterior or a real effect: with a forward model that is slightly wrong, extra
readings can sharpen belief onto a confidently wrong answer instead of the right one.
Worth knowing which, because it applies to our engine too.
"""
include harness;

glob PROBE_COUNTS: list = [1, 3, 8, 15];

with entry {
    for n in [root-->] { del n; }
    root spawn IngestNetwork();
    root spawn BuildForwardModel();
    print(f"\nNet2, {len(NODES)} junctions - does more measurement help?\n");
    print("  probes | top-1  | top-5  | mean hops");
    for np in PROBE_COUNTS {
        t1 = 0; t5 = 0; hp = 0.0; k = 0;
        for (i, t) in enumerate(NODES) {
            root spawn StageIncident(truth=t, seed=3000 + i);
            r = root spawn RunArm(truth=t, arm="info", probes=np, draws=110);
            if r.rank == 1 { t1 += 1; }
            if r.rank <= 5 { t5 += 1; }
            hp += r.hops; k += 1;
        }
        print(f"    {np:>3}  | {100.0*t1/k:5.1f}% | {100.0*t5/k:5.1f}% |   {hp/k:.2f}");
    }
}
