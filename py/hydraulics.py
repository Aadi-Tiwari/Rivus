"""EPANET boundary. This file exists only because EPANET is a C library.

Everything PipeTrace actually reasons about — belief over leak locations, expected
information gain, what pressure cannot resolve, which customers a valve plan strands —
lives in Jac. This module does two things: read the network, and run a snapshot.

No Bayes, no scoring, no graph logic here. Deliberately.
"""
from __future__ import annotations

import wntr

M_TO_PSI = 1.4219702063247


def topology(inp_path: str) -> dict:
    """Junctions, pipe endpoints, coordinates and demands, as plain dicts for Jac."""
    wn = wntr.network.WaterNetworkModel(inp_path)
    junctions = list(wn.junction_name_list)
    return {
        "junctions": junctions,
        "pipes": [[p, wn.get_link(p).start_node_name, wn.get_link(p).end_node_name]
                  for p in wn.pipe_name_list],
        "coords": {n: list(wn.get_node(n).coordinates) for n in wn.node_name_list},
        # Net2 carries a negative base demand at one node (it acts as an inflow), so
        # district consumption is the positive part only.
        "demand_lps": sum(max(float(wn.get_node(j).base_demand or 0.0), 0.0)
                          for j in junctions) * 1000.0,
        "sources": wn.tank_name_list + wn.reservoir_name_list,
    }


def snapshot(inp_path: str,
             leak_node: str | None = None,
             leak_c: float = 0.0,
             demand_mult: dict | None = None,
             rough_mult: dict | None = None,
             closed_pipes: list | None = None,
             interconnect_from: str | None = None,
             interconnect_head_m: float = 0.0,
             pdd: bool = False,
             service_min_psi: float = 20.0) -> dict:
    """One steady-state hydraulic snapshot. Returns junction pressures in psi.

    `pdd` switches to pressure-dependent demand, which is what makes a valve-closure
    result meaningful: stranded nodes report their real pressure loss instead of
    drawing water they cannot physically receive.
    """
    wn = wntr.network.WaterNetworkModel(inp_path)
    wn.options.time.duration = 0

    if pdd:
        wn.options.hydraulic.demand_model = "PDA"
        wn.options.hydraulic.required_pressure = service_min_psi / M_TO_PSI
        wn.options.hydraulic.minimum_pressure = 0.0

    if demand_mult:
        for j in wn.junction_name_list:
            for d in wn.get_node(j).demand_timeseries_list:
                d.base_value *= demand_mult.get(j, 1.0)

    if rough_mult:
        for p in wn.pipe_name_list:
            wn.get_link(p).roughness *= rough_mult.get(p, 1.0)

    if leak_node:
        wn.get_node(leak_node).emitter_coefficient = leak_c

    for p in (closed_pipes or []):
        wn.get_link(p).initial_status = wntr.network.LinkStatus.Closed

    if interconnect_from:
        x, y = wn.get_node(interconnect_from).coordinates
        wn.add_reservoir("BACKUP", base_head=interconnect_head_m,
                         coordinates=(x + 2.0, y + 2.0))
        wn.add_pipe("BACKUP_MAIN", "BACKUP", interconnect_from,
                    length=50.0, diameter=0.30, roughness=130.0)

    result = wntr.sim.EpanetSimulator(wn).run_sim()
    row = result.node["pressure"].iloc[0] * M_TO_PSI
    return {j: float(row[j]) for j in wn.junction_name_list}
