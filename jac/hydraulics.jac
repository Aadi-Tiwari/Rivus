"""PipeTrace — the EPANET boundary.

This module exists only because EPANET is a C library and wntr is its Python driver.
It does two things: read the network, and run one steady-state snapshot. No Bayes, no
scoring, no graph logic. Deliberately.

Everything PipeTrace reasons about lives in Jac, and so does this boundary now: the
wntr calls are the only Python that survives, and they are made from Jac.
"""

import wntr;

glob M_TO_PSI: float = 1.4219702063247;


def topology(inp_path: str) -> dict {
    """Junctions, pipe endpoints, coordinates and demands, as plain dicts.""";
    wn = wntr.network.WaterNetworkModel(inp_path);
    junctions = list(wn.junction_name_list);

    pipes = [];
    for p in wn.pipe_name_list {
        link = wn.get_link(p);
        pipes.append([p, link.start_node_name, link.end_node_name]);
    }

    coords = {};
    for n in wn.node_name_list { coords[n] = list(wn.get_node(n).coordinates); }

    # Net2 carries a negative base demand at one node (it acts as an inflow), so
    # district consumption is the positive part only.
    demand_lps = 0.0;
    for j in junctions {
        base = wn.get_node(j).base_demand;
        if not base { base = 0.0; }
        demand_lps += max(float(base), 0.0);
    }

    return {
        "junctions": junctions,
        "pipes": pipes,
        "coords": coords,
        "demand_lps": demand_lps * 1000.0,
        "sources": wn.tank_name_list + wn.reservoir_name_list
    };
}


def snapshot(inp_path: str, leak_node: any = None, leak_c: float = 0.0,
             demand_mult: any = None, rough_mult: any = None,
             closed_pipes: any = None, interconnect_from: any = None,
             interconnect_head_m: float = 0.0, pdd: bool = False,
             service_min_psi: float = 20.0) -> dict {
    """One steady-state hydraulic snapshot. Returns junction pressures in psi.

    `pdd` switches to pressure-dependent demand, which is what makes a valve-closure
    result meaningful: stranded nodes report their real pressure loss instead of
    drawing water they cannot physically receive.
    """;
    wn = wntr.network.WaterNetworkModel(inp_path);
    wn.options.time.duration = 0;

    if pdd {
        wn.options.hydraulic.demand_model = "PDA";
        wn.options.hydraulic.required_pressure = service_min_psi / M_TO_PSI;
        wn.options.hydraulic.minimum_pressure = 0.0;
    }

    if demand_mult {
        for j in wn.junction_name_list {
            for d in wn.get_node(j).demand_timeseries_list {
                d.base_value *= demand_mult.get(j, 1.0);
            }
        }
    }

    if rough_mult {
        for p in wn.pipe_name_list {
            wn.get_link(p).roughness *= rough_mult.get(p, 1.0);
        }
    }

    if leak_node { wn.get_node(leak_node).emitter_coefficient = leak_c; }

    if closed_pipes {
        for p in closed_pipes {
            wn.get_link(p).initial_status = wntr.network.LinkStatus.Closed;
        }
    }

    if interconnect_from {
        xy = wn.get_node(interconnect_from).coordinates;
        wn.add_reservoir("BACKUP", base_head=interconnect_head_m,
                         coordinates=(xy[0] + 2.0, xy[1] + 2.0));
        wn.add_pipe("BACKUP_MAIN", "BACKUP", interconnect_from,
                    length=50.0, diameter=0.30, roughness=130.0);
    }

    result = wntr.sim.EpanetSimulator(wn).run_sim();
    row = result.node["pressure"].iloc[0] * M_TO_PSI;

    out = {};
    for j in wn.junction_name_list { out[j] = float(row[j]); }
    return out;
}

def flows(inp_path: str) -> dict {
    """Steady-state pipe flow magnitudes in gpm, keyed by pipe id.

    The board animates each pipe at a rate set by how much water it carries, so the
    figure needs real flows rather than a constant. EPANET reports them in m3/s.
    """;
    wn = wntr.network.WaterNetworkModel(inp_path);
    wn.options.time.duration = 0;
    result = wntr.sim.EpanetSimulator(wn).run_sim();
    row = result.link["flowrate"].iloc[0];
    out = {};
    for p in wn.pipe_name_list { out[p] = abs(float(row[p])) * 15850.323; }
    return out;
}
