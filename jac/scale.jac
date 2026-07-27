"""Does probe selection work at all, or only fail on a small network?

On Net2 (35 junctions, 20.4 L/s) information-gain probing is not distinguishably better
than random. That is either a fact about the method or a fact about the network: Net2 has
179 of 210 candidate pairs hydraulically indistinguishable, which leaves very little for
any probe policy to exploit.

Net3 is 92 junctions, 117 pipes, 192.6 L/s, five sources. This runs the same measurement
there. The answer is worth having either way: if the lift appears, the method needs
network structure rather than being broken; if it does not, we say so.
"""

include harness;

import json;


glob NETS: list = [
    ["data/net2.inp", 0.002, "Net2  35 junctions,  20.4 L/s"],
    ["data/net3.inp", 0.02,  "Net3  92 junctions, 192.6 L/s"]
];


with entry {
    results = [];
    for cfg in NETS {
        CONFIG["inp"] = cfg[0];
        CONFIG["leak_c"] = cfg[1];
        for n in [root-->] { del n; }
        ing = root spawn IngestNetwork();
        root spawn BuildForwardModel();

        # how much of the network is even distinguishable?
        root spawn StageIncident(truth=NODES[0], seed=1);
        fused = 0; pairs = 0;
        hyps = of_type([root-->], Hypothesis);
        a = 0;
        while a < 12 {
            b = a + 1;
            while b < 12 {
                worst = 0.0;
                for i in range(len(NODES)) {
                    d = abs(hyps[a].signature[i] - hyps[b].signature[i]);
                    if d > worst { worst = d; }
                }
                if worst < 2.0 * sigma() { fused += 1; }
                pairs += 1;
                b += 1;
            }
            a += 1;
        }

        ih = 0.0; rh = 0.0; i1 = 0; r1 = 0; i5 = 0; r5 = 0; k = 0;
        for (i, t) in enumerate(NODES) {
            root spawn StageIncident(truth=t, seed=2000 + i);
            x = root spawn RunArm(truth=t, arm="info");
            ih += x.hops;
            if x.rank == 1 { i1 += 1; }
            if x.rank <= 5 { i5 += 1; }
            root spawn StageIncident(truth=t, seed=2000 + i);
            y = root spawn RunArm(truth=t, arm="random");
            rh += y.hops;
            if y.rank == 1 { r1 += 1; }
            if y.rank <= 5 { r5 += 1; }
            k += 1;
        }
        lift = (1.0 - (ih / k) / (rh / k)) * 100.0;
        print(f"\n{cfg[2]}   leak {leak_c()} emitter   {k} incidents");
        print(f"  indistinguishable pairs in a 12-candidate sample: {fused}/{pairs}");
        print(f"  top-1   info {100.0*i1/k:5.1f}%   random {100.0*r1/k:5.1f}%");
        print(f"  top-5   info {100.0*i5/k:5.1f}%   random {100.0*r5/k:5.1f}%");
        print(f"  hops    info {ih/k:5.2f}    random {rh/k:5.2f}    lift {lift:+.0f}%");
        results.append({"net": cfg[2], "junctions": len(NODES), "incidents": k,
                        "fused": fused, "pairs": pairs,
                        "info_top1": 100.0*i1/k, "rand_top1": 100.0*r1/k,
                        "info_top5": 100.0*i5/k, "rand_top5": 100.0*r5/k,
                        "info_hops": ih/k, "rand_hops": rh/k, "lift": lift});
    }
    with open("web/measured.json", "w") as f { json.dump(results, f, indent=1); }
    print(f"\n[export] web/measured.json written");
}
