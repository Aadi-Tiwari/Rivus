"""PipeTrace — the network, as a graph.

The water network is not modelled as a graph for convenience. It IS a graph: junctions
joined by pipes, water moving along the edges. This half owns the physical model: the
schema, the scenario constants, ingestion, the forward model, and staging an incident.

Everything that reasons about that model lives in diagnose.jac.

Python appears once, at the EPANET boundary, because EPANET is a C library.
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


def sigma() -> float {
    return math.sqrt(GAUGE_NOISE ** 2 + MODEL_ERROR ** 2);
}

def of_type(items: list, kind: type) -> list {
    """Filter a neighbour list by node type.

    jaclang 0.16.7 rejects the backtick type-filter form, the same parser path that
    breaks the root-entry ability form. This does the same job explicitly.
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

node Source {
    """A tank or reservoir. Without these in the graph the walker cannot see where
    water enters, and its reachability answer would disagree with the hydraulics."""
    has name: str;
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
        for sname in topo["sources"] {
            sn = Source(name=sname);
            made[sname] = sn;
            here ++> sn;
        }
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

glob OBSERVED: dict = {};
glob META: dict = {};   # mutated in place, unlike a glob rebind

walker StageIncident {
    """Hides a leak and produces what a crew would actually read.

    The observations come from a PERTURBED model: demands and pipe roughness are
    shifted before the truth snapshot is taken. Without this the diagnosis would be
    inverting the same simulator that produced the evidence, which proves nothing.
    """
    has truth: str;
    has seed: int = 7;
    has leak_lps: float = 0.0;

    can stage with entry {
        random.seed(self.seed);
        dm = {};
        rm = {};
        topo = topology(INP);
        for j in topo["junctions"] { dm[j] = random.lognormvariate(0.0, DEMAND_CV); }
        for p in topo["pipes"] { rm[p[0]] = random.lognormvariate(0.0, ROUGH_CV); }

        base = snapshot(INP, demand_mult=dm, rough_mult=rm);
        leak = snapshot(INP, leak_node=self.truth, leak_c=LEAK_C,
                        demand_mult=dm, rough_mult=rm);
        OBSERVED.clear();
        for j in NODES { OBSERVED[j] = leak[j] - base[j]; }

        head_m = base[self.truth] / 1.4219702063247;
        if head_m < 0.0 { head_m = 0.0; }
        self.leak_lps = LEAK_C * math.sqrt(head_m) * 1000.0;

        # the junction the supply main ties into, for isolation flooding
        for p in topo["pipes"] {
            if p[1] in topo["sources"] { META["supply"] = p[2]; }
            elif p[2] in topo["sources"] { META["supply"] = p[1]; }
        }
    }
}


def read_gauge(location: str) -> float {
    """One field measurement: the true residual plus gauge noise.""";
    return OBSERVED[location] + random.gauss(0.0, GAUGE_NOISE);
}


