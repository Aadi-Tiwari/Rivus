"""PipeTrace — active leak diagnosis for water distribution networks.

The water network is not modelled as a graph for convenience. It IS a graph: junctions
joined by pipes, water moving along the edges. Walkers traverse the same topology the
water does, and belief about where the leak is lives on the graph as node state.

Python is used for exactly one thing: calling EPANET, which is a C library. Every
decision in this system — what to measure next, what the evidence implies, what cannot
be resolved, which customers a valve plan strands — is computed here.
"""

import math;
import random;
import from py.hydraulics { topology, snapshot }

# --------------------------------------------------------------------- scenario
glob INP: str = "data/net2.inp";
glob LEAK_C: float = 0.002;          # emitter coeff; ~15 L/s, a main break
glob GAUGE_NOISE: float = 0.35;      # psi, field pressure gauge
glob MODEL_ERROR: float = 0.50;      # psi, forward-model error allowance
glob DEMAND_CV: float = 0.08;        # truth-model perturbation
glob ROUGH_CV: float = 0.10;
glob CRITICAL_NODE: str = "35";      # designated critical facility
glob CRITICAL_MIN_PSI: float = 30.0;
glob SERVICE_MIN_PSI: float = 20.0;
glob INTERCONNECT_FROM: str = "30";  # normally-closed emergency supply
glob INTERCONNECT_HEAD: float = 60.0;
glob CREW_SPEED: float = 1.2;        # map units per minute

glob NODES: list = [];               # canonical junction order
glob SIGMA: float = 0.0;


def sigma() -> float {
    return math.sqrt(GAUGE_NOISE ** 2 + MODEL_ERROR ** 2);
}

def of_type(items: list, kind: type) -> list {
    """Filter a neighbour list by node type.

    jaclang 0.16.7 rejects the backtick type-filter form the backtick type-filter form, the same
    parser path that breaks the root-entry ability form. This does the same job explicitly.
    """;
    out = [];
    for x in items { if isinstance(x, kind) { out.append(x); } }
    return out;
}

# ---------------------------------------------------------------- graph schema
node Junction {
    has name: str;
    has x: float = 0.0;
    has y: float = 0.0;
    has baseline_psi: float = 0.0;
    has is_critical: bool = False;
    has measured: bool = False;
    has reading_psi: float = 0.0;
}

edge Pipe {
    has pid: str;
    has closed: bool = False;
}

node Hypothesis {
    """A candidate leak location and the belief currently attached to it."""
    has location: str;
    has prob: float = 0.0;
    has signature: list = [];        # predicted psi change at every junction
}

node Observation {
    has step: int;
    has location: str;
    has reading_psi: float;
    has info_bits: float;
    has travel_min: float;
    has survivors: int;
    has entropy_bits: float;
}

node Finding {
    has kind: str;
    has verdict: str;
    has detail: str;
}

# ------------------------------------------------------------------- ingestion
walker IngestNetwork {
    """Builds the physical network as a Jac graph: junctions as nodes, pipes as edges."""
    has junctions: int = 0;
    has pipes: int = 0;
    has demand_lps: float = 0.0;

    can build with entry {
        topo = topology(INP);
        base = snapshot(INP);
        self.demand_lps = topo["demand_lps"];
        NODES.clear();
        for j in topo["junctions"] { NODES.append(j); }

        made = {};
        for j in topo["junctions"] {
            c = topo["coords"][j];
            n = Junction(name=j, x=c[0], y=c[1], baseline_psi=base[j],
                         is_critical=(j == CRITICAL_NODE));
            made[j] = n;
            here ++> n;
            self.junctions += 1;
        }
        for p in topo["pipes"] {
            if p[1] in made and p[2] in made {
                made[p[1]] +>:Pipe(pid=p[0]):+> made[p[2]];
                self.pipes += 1;
            }
        }
        print(f"[ingest] {self.junctions} junctions, {self.pipes} pipe edges, "
              f"{self.demand_lps:.1f} L/s district draw");
    }
}

# ---------------------------------------------------------------- forward model
walker BuildForwardModel {
    """One EPANET run per candidate leak location.

    A leak anywhere moves pressure everywhere, so a single simulation yields the
    predicted reading at every possible probe site. That is why this is affordable.
    """
    has count: int = 0;
    has seconds: float = 0.0;

    can build with entry {
        import time;
        t0 = time.time();
        base = snapshot(INP);
        n = len(NODES);
        for h in NODES {
            p = snapshot(INP, leak_node=h, leak_c=LEAK_C);
            sig = [];
            for j in NODES { sig.append(p[j] - base[j]); }
            here ++> Hypothesis(location=h, prob=1.0 / n, signature=sig);
            self.count += 1;
        }
        self.seconds = time.time() - t0;
        print(f"[forward] {self.count + 1} EPANET runs in {self.seconds:.2f}s "
              f"({(self.seconds / (self.count + 1)) * 1000:.0f} ms each)");
    }
}

# -------------------------------------------------------------------- inference
walker ScoreProbes {
    """Ranks every possible measurement by expected information gain.

    I(Y;H) = h(Y) - h(Y|H). The conditional term is the entropy of a single Gaussian
    and is identical at every location, so ranking by the predictive mixture entropy
    h(Y) ranks by information gain. Estimated by Monte Carlo, here, in Jac.
    """
    has crew_at: str = "1";
    has cost_aware: bool = True;
    has draws: int = 300;
    has ranked: list = [];

    can score with entry {
        hyps = of_type([-->], Hypothesis);
        probs = [];
        for h in hyps { probs.append(h.prob); }
        juncs = of_type([-->], Junction);
        crew = None;
        for j in juncs { if j.name == self.crew_at { crew = j; } }

        out = [];
        for (col, name) in enumerate(NODES) {
            target = None;
            for j in juncs { if j.name == name { target = j; } }
            if target == None or target.measured { continue; }

            mu = [];
            for h in hyps { mu.append(h.signature[col]); }
            bits = self.mixture_entropy(mu, probs);
            mins = self.travel(crew, target);
            score = bits;
            if self.cost_aware { score = bits / (mins / 60.0); }
            out.append([score, name, bits, mins]);
        }
        out.sort(reverse=True);   # [score, name, bits, mins] — score leads
        self.ranked = out;
    }

    def mixture_entropy(mu: list, probs: list) -> float {
        """Differential entropy of the predictive Gaussian mixture, by Monte Carlo.""";
        s = SIGMA;
        total = 0.0;
        i = 0;
        while i < self.draws {
            k = self.sample_index(probs);
            y = mu[k] + random.gauss(0.0, s);
            dens = 0.0;
            for (m, w) in zip(mu, probs) {
                dens += w * math.exp(-0.5 * ((y - m) / s) ** 2);
            }
            if dens < 1e-300 { dens = 1e-300; }
            total += -math.log2(dens);
            i += 1;
        }
        return total / self.draws;
    }

    def sample_index(probs: list) -> int {
        r = random.random();
        acc = 0.0;
        for (i, p) in enumerate(probs) {
            acc += p;
            if r <= acc { return i; }
        }
        return len(probs) - 1;
    }

    def travel(a: Junction, b: Junction) -> float {
        d = math.hypot(b.x - a.x, b.y - a.y);
        m = d / CREW_SPEED;
        if m < 1.0 { return 1.0; }
        return m;
    }
}

walker TakeProbe {
    """Applies one field measurement and updates belief on every hypothesis node."""
    has location: str;
    has reading: float;
    has survivors: int = 0;
    has entropy_bits: float = 0.0;
    has top: str = "";
    has top_prob: float = 0.0;

    can apply with entry {
        col = NODES.index(self.location);
        hyps = of_type([-->], Hypothesis);
        total = 0.0;
        for h in hyps {
            like = math.exp(-0.5 * ((self.reading - h.signature[col]) / SIGMA) ** 2);
            h.prob = h.prob * like;
            total += h.prob;
        }
        if total <= 1e-300 {
            # Every hypothesis contradicted. Fall back to the prior rather than
            # invent a winner out of floating-point noise.
            for h in hyps { h.prob = 1.0 / len(hyps); }
        } else {
            for h in hyps { h.prob = h.prob / total; }
        }

        for j in of_type([-->], Junction) {
            if j.name == self.location {
                j.measured = True;
                j.reading_psi = self.reading;
            }
        }

        ent = 0.0;
        best = 0.0;
        for h in hyps {
            if h.prob > 0.0 { ent += -h.prob * math.log2(h.prob); }
            if h.prob > best { best = h.prob; self.top = h.location; }
        }
        self.entropy_bits = ent;
        self.top_prob = best;
        self.survivors = len(credible_set(hyps, 0.90));
    }
}


def credible_set(hyps: list, mass: float) -> list {
    """Smallest set of hypotheses holding 'mass' of the belief.""";
    pairs = [];
    for h in hyps { pairs.append([h.prob, h.location]); }
    pairs.sort(reverse=True);     # [prob, location] — prob leads
    out = [];
    acc = 0.0;
    for p in pairs {
        out.append(p[1]);
        acc += p[0];
        if acc >= mass { break; }
    }
    return out;
}

# ------------------------------------------------------------- identifiability
walker CheckIdentifiability {
    """Reports what pressure measurement cannot resolve, and the sensor move that would.

    Two junctions on the same branch push pressure around almost identically everywhere.
    No probe sequence separates them, because the information is not there. Rather than
    hide that behind a confident top-1, this names the pairs.
    """
    has survivors: list = [];
    has blocked: list = [];
    has n_pairs: int = 0;
    has verdict: str = "";
    has advice_node: str = "";
    has advice_sep: float = 0.0;

    can check with entry {
        hyps = of_type([-->], Hypothesis);
        self.survivors = credible_set(hyps, 0.90);
        byloc = {};
        for h in hyps { byloc[h.location] = h; }

        threshold = 2.0 * SIGMA;
        n = len(self.survivors);
        self.n_pairs = n * (n - 1) // 2;

        a = 0;
        while a < n {
            b = a + 1;
            while b < n {
                sa = byloc[self.survivors[a]].signature;
                sb = byloc[self.survivors[b]].signature;
                worst = 0.0;
                where = "";
                for (i, name) in enumerate(NODES) {
                    d = abs(sa[i] - sb[i]);
                    if d > worst { worst = d; where = name; }
                }
                if worst < threshold {
                    # separation leads so a plain sort orders by how fused the pair is
                    self.blocked.append([worst, self.survivors[a],
                                         self.survivors[b], where]);
                }
                b += 1;
            }
            a += 1;
        }
        self.blocked.sort();

        # Best place for one more gauge: maximise the WORST pairwise separation, so
        # the winner separates every survivor rather than the easiest pair.
        best_node = "";
        best_sep = -1.0;
        for (i, name) in enumerate(NODES) {
            worst_here = 1e9;
            a2 = 0;
            while a2 < n {
                b2 = a2 + 1;
                while b2 < n {
                    d = abs(byloc[self.survivors[a2]].signature[i]
                            - byloc[self.survivors[b2]].signature[i]);
                    if d < worst_here { worst_here = d; }
                    b2 += 1;
                }
                a2 += 1;
            }
            if worst_here > best_sep { best_sep = worst_here; best_node = name; }
        }
        self.advice_node = best_node;
        self.advice_sep = best_sep;

        if n < 2 { self.verdict = "IDENTIFIED"; }
        elif best_sep >= threshold { self.verdict = "IDENTIFIABLE_WITH_ONE_MORE_SENSOR"; }
        elif len(self.blocked) == self.n_pairs {
            self.verdict = "NOT_IDENTIFIABLE_FROM_PRESSURE";
        } else { self.verdict = "PARTIALLY_IDENTIFIABLE"; }

        here ++> Finding(kind="identifiability", verdict=self.verdict,
                         detail=f"{len(self.blocked)} of {self.n_pairs} surviving pairs "
                                f"cannot be separated by any single gauge");
    }
}

# ------------------------------------------------------------------- isolation
walker FloodFromSource {
    """Finds every junction still fed, by walking open pipe edges.

    This is the isolation question answered as a graph traversal rather than a
    simulation: close a segment, flood the network from the supply, and whatever the
    walker cannot reach has lost service. The hydraulic model then confirms it
    independently.
    """
    has reached: list = [];

    can start with Junction entry {
        if here.name in self.reached { disengage; }
        self.reached.append(here.name);
        visit [edge ->:Pipe:closed == False:->];
        visit [edge <-:Pipe:closed == False:<-];
    }
}
