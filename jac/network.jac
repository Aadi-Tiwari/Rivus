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
# Residual uncertainty in today's district demand, AFTER the inlet meter. A district
# metered area has a flow meter at its inlet, so consumption is partly observed rather
# than unknown; 0.12 is what is left over. Measured sensitivity is in the README: the
# method's lift over random probing runs from +13% at 0.05 to roughly nothing by 0.25.
glob DEMAND_CV: float = 0.12;
glob ROUGH_CV: float = 0.10;
glob CRITICAL_NODE: str = "35";      # designated critical facility
glob CRITICAL_MIN_PSI: float = 30.0;
glob SERVICE_MIN_PSI: float = 20.0;
glob INTERCONNECT_FROM: str = "30";  # normally-closed emergency supply
glob INTERCONNECT_HEAD: float = 60.0;
glob CREW_SPEED: float = 1.2;        # map units per minute
glob LEAK_SIZE_CV: float = 0.30;     # the real break size is unknown to the diagnosis

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

