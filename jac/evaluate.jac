include simulate;
import from hydraulics { topology, run }

def hop_table(junctions: list, pipes: list) -> dict {
    "All-pairs hop distance by breadth-first search over the pipe topology.";
    adj = {};
    for j in junctions { adj[j] = []; }
    for p in pipes {
        a = p["from"]; b = p["to"];
        if a in adj and b in adj {
            adj[a].append(b);
            adj[b].append(a);
        }
    }
    table = {};
    for src in junctions {
        dist = {src: 0};
        frontier = [src];
        while len(frontier) > 0 {
            nxt = [];
            for u in frontier {
                for v in adj[u] {
                    if v not in dist {
                        dist[v] = dist[u] + 1;
                        nxt.append(v);
                    }
                }
            }
            frontier = nxt;
        }
        table[src] = dist;
    }
    return table;
}

def hops(table: dict, a: str, b: str) -> int {
    "Hop distance, with a fixed penalty when the two sit in disconnected components.";
    if a in table and b in table[a] { return table[a][b]; }
    return 9;
}

def pick_random(remaining: list, state: int) -> tuple {
    "Control arm: choose the next gauge uniformly at random.";
    pair = lcg_unit(state);
    idx = int(pair[0] * len(remaining));
    if idx >= len(remaining) { idx = len(remaining) - 1; }
    return (remaining[idx], pair[1]);
}

def pick_best(remaining: list, post: dict, model: dict, cands: list,
              readings: dict, seen: list) -> tuple {
    "Treatment arm: choose the gauge with the highest expected information gain.";
    best = ""; bestv = -1.0;
    for g in remaining {
        v = expected_information(g, post, model, cands, readings, seen);
        if v > bestv { bestv = v; best = g; }
    }
    return (best, bestv);
}

def run_arm(arm: str, budget: int, threshold: float, truth: str, gauges: list,
            model: dict, cands: list, readings: dict, state: int) -> dict {
    "Run one probing policy on one incident. Returns rank of truth and probes spent.";
    seen = []; remaining = [];
    for g in gauges { remaining.append(g); }
    s = state;
    while len(seen) < budget and len(remaining) > 0 {
        post = posterior(readings, model, cands, seen);
        if arm == "random" {
            pr = pick_random(remaining, s);
            pick = pr[0]; s = pr[1];
        } else {
            pr = pick_best(remaining, post, model, cands, readings, seen);
            pick = pr[0];
            if arm == "adaptive" and pr[1] < threshold { break; }
        }
        seen.append(pick);
        remaining.remove(pick);
    }
    post = posterior(readings, model, cands, seen);
    r = rank_desc(post);
    return {"rank": r.index(truth) + 1, "top": r[0], "probes": len(seen)};
}

with entry {
    t = topology();
    cands = t["junctions"]; gauges = t["gauges"];
    pids = []; for pp in t["pipes"] { pids.append(pp["id"]); }
    tbl = hop_table(cands, t["pipes"]);
    set_leak(400.0);
    CFG["model_sigma"] = 1.30;
    model = build_forward_model(cands);
    seeds = [1, 2, 3];

    ds = 0.0; ok = 0; nn = 0; worst = 1.0e9;
    for seed in seeds {
        for c in cands {
            inc = stage_incident(c, gauges, pids, seed);
            d = divergence_stats(model[c], inc["perturbed"], gauges);
            ds += d["median"];
            if d["median"] < worst { worst = d["median"]; }
            if d["ok"] { ok += 1; }
            nn += 1;
        }
    }
    print("NON-CIRCULARITY GATE (perturbed truth vs nominal model, noise floor", CFG["noise"], "psi)");
    print("   median divergence", round(ds / nn, 3), "psi | worst incident", round(worst, 3),
          "psi | incidents clearing noise", round(100.0 * ok / nn, 1), "percent");
    if worst <= CFG["noise"] {
        print("   GATE WARNING: at least one incident does not clear the noise floor.");
    } else {
        print("   GATE PASS: every incident diverges by more than gauge noise.");
    }
    print("");
    print("arm            exact%  top5%  mean_hops  mean_probes   n");
    arms = [("random", 3, 0.0), ("max-infogain", 3, 0.0),
            ("adaptive", 8, 0.03), ("all-gauges", 8, 0.0)];
    for a in arms {
        name = a[0]; budget = a[1]; th = a[2];
        mode = name;
        if name == "all-gauges" { mode = "best"; }
        if name == "max-infogain" { mode = "best"; }
        hit = 0; t5 = 0; hp = 0; pb = 0; n = 0; st = 991;
        for seed in seeds {
            for c in cands {
                inc = stage_incident(c, gauges, pids, seed);
                res = run_arm(mode if name != "adaptive" else "adaptive",
                              budget, th, c, gauges, model, cands, inc["readings"], st);
                st = lcg_next(st);
                if res["rank"] == 1 { hit += 1; }
                if res["rank"] <= 5 { t5 += 1; }
                hp += hops(tbl, res["top"], c);
                pb += res["probes"]; n += 1;
            }
        }
        print("  ", name.ljust(13), round(100.0*hit/n,1), "  ", round(100.0*t5/n,1),
              "  ", round(hp/n,2), "  ", round(pb/n,2), "  ", n);
    }
}
