"""EPANET calls only. No numerical logic lives here; that belongs in Jac."""
import os, inspect, warnings
import wntr

warnings.filterwarnings("ignore")
_NET = os.path.join(os.path.dirname(inspect.getfile(wntr)),
                    "tests", "networks_for_testing", "Anytown_multipointcurves.inp")
_CACHE = {}


def _model():
    wn = wntr.network.WaterNetworkModel(_NET)
    wn.options.time.duration = 0
    return wn


def topology() -> dict:
    """Junction ids, pipe endpoints and gauge ids. Pure structure, no hydraulics."""
    wn = _model()
    pipes = []
    for name in wn.pipe_name_list:
        p = wn.get_link(name)
        pipes.append({"id": name, "from": p.start_node_name, "to": p.end_node_name})
    js = list(wn.junction_name_list)
    return {"junctions": js, "pipes": pipes, "gauges": js[::3]}


def run(leak_junction: str = "", leak_gpm: float = 0.0,
        demand_scale: dict = None, roughness_scale: dict = None) -> dict:
    """One EPANET solve. Leak is modelled as added demand in GPM. Returns {junction_id: pressure}."""
    key = (leak_junction, leak_gpm,
           None if demand_scale is None else tuple(sorted(demand_scale.items())),
           None if roughness_scale is None else tuple(sorted(roughness_scale.items())))
    if key in _CACHE:
        return _CACHE[key]
    wn = _model()
    if demand_scale:
        for j, s in demand_scale.items():
            node = wn.get_node(j)
            for ts in node.demand_timeseries_list:
                ts.base_value = ts.base_value * s
    if roughness_scale:
        for pid, s in roughness_scale.items():
            wn.get_link(pid).roughness = wn.get_link(pid).roughness * s
    if leak_junction and leak_gpm > 0.0:
        node = wn.get_node(leak_junction)
        ts = node.demand_timeseries_list[0]
        ts.base_value = ts.base_value + leak_gpm * 6.30902e-5
    res = wntr.sim.EpanetSimulator(wn).run_sim()
    row = res.node["pressure"].iloc[0]
    out = {j: float(row[j]) for j in wn.junction_name_list}
    _CACHE[key] = out
    return out
