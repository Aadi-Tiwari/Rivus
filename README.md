# Rivus

A water-network simulation prototype for choosing the next pressure measurement and comparing valve-isolation plans.

Rivus represents pipes, junctions, sources, and leak hypotheses as a Jac graph. EPANET simulations provide pressure predictions. Graph walkers rank candidate measurements, report leaks that pressure observations cannot distinguish, and compare isolation plans using both network reachability and pressure-dependent hydraulics.

## Run locally

The pinned environment uses Python 3.13 with Jac, WNTR, and byLLM:

```sh
python -m venv .venv
```

Activate the environment, then:

```sh
python -m pip install -r requirements.txt
python -m unittest discover -s tests
python run.py test
python run.py demo
```

`run.py` works on Windows, macOS, and Linux. It clears the project's generated Jac state before each invocation so repeated runs do not accumulate duplicate networks.

Other modes:

```sh
python run.py intake
python run.py eval
```

Field-note intake uses a deterministic parser when `OPENAI_API_KEY` is absent. Configuring the optional provider can send field-note text to that service. The hydraulic and graph calculations do not require a language model.

## View the incident board

The demo writes `web/trace.json`. Serve the repository after running it:

```sh
python -m http.server 8080 --bind 127.0.0.1
```

Open <http://127.0.0.1:8080/web/board.html>. `web/standalone.html` contains an embedded snapshot and does not automatically update when a new trace is generated.

## Source map

| Path | Responsibility |
| --- | --- |
| `jac/network.jac` | Network schema and scenario configuration |
| `jac/simulate.jac` | Forward model, belief updates, and information gain |
| `jac/graphops.jac` | Probe ranking, identifiability, and valve search |
| `jac/intake.jac` | Field-note parsing |
| `jac/evaluate.jac` and `jac/scale.jac` | Evaluation harnesses and control policies |
| `py/hydraulics.py` | WNTR/EPANET boundary |
| `jac/test_pipetrace.jac` | Regression and consistency checks |

## Interpreting the results

This is a simulation study using sample networks. The configured critical facility and emergency supply are scenario assumptions, not verified utility infrastructure. Isolation results describe modeled service impact and do not authorize operating real valves.

An earlier localization improvement claim was withdrawn after the truth-model perturbation cancelled during differencing. The evaluation code now includes a non-circularity check. Results depend on network identifiability and the assumed noise and incident models; the small sample network did not establish a consistent advantage over random probing.

Run the evaluation harness to inspect the current environment's results. Historical output and source comments are not fresh performance measurements. This README makes no field-accuracy or runtime guarantee.

The experimental REST entry point in `jac/serve.jac` requires authentication on the pinned Jac version. The supported local demonstration path is the CLI plus static board.
