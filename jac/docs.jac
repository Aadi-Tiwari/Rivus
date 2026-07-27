"""PipeTrace - the written sheets, held in Jac.

Method, Results and Limits are the argument the project makes in prose, so they live
next to the code that produces the numbers rather than inside the React tree. This
module owns their text and structure and emits one data file the site renders:

    jac run jac/docs.jac      ->  web/generated/docs.json

A sheet is a masthead plus an ordered list of notes. A note is a marginal quantity,
a heading, and blocks. Four block kinds, matching the report components the site
already has: a paragraph, a callout with an optional warn tone, a called-out
expression, and a ruled readout table. Asterisks in a title line mark the italic
run, which is the only inline styling any sheet needs.
"""

import json;
import os;


glob METHOD: dict = {
    "sheet": "Sheet 01 / Method",
    "title": ["How Rivus", "*narrows* a leak"],
    "lede": "A hydraulic forward model, a likelihood that admits its own error, and a probe policy that stops once the next crew is no longer worth sending.",
    "meta": ["Anytown multipointcurves", "22 junctions", "8 gauges", "leak 400 gpm"],
    "notes": [
        {
            "mark": "43", "markUnit": "pipes solved", "heading": "The forward model",
            "blocks": [
                {"p": "EPANET solves pressures at every junction for a candidate leak. The network is Anytown_multipointcurves, a published benchmark bundled with wntr. Of the 33 bundled networks only 8 produce physically valid hydraulics, and plain Anytown.inp diverges to 1e25."},
                {"p": "Leaks enter as added demand in GPM, not as emitters. Emitter leaks saturate: 0.5 and 30.0 produced identical 30 psi drops and drove junctions negative. Added demand stays linear and controllable."}
            ]
        },
        {
            "mark": "1.34", "markUnit": "psi combined σ",
            "heading": "Why gauge noise alone is not the likelihood",
            "blocks": [
                {"p": "The obvious likelihood compares predicted against observed pressure using the 0.35 psi sensor noise. Applied to perturbed data it reported entropy 0.000 while being wrong 95% of the time."},
                {"callout": "Certainty and error at once is the worst available failure for a product whose whole claim is that it reports what it cannot know.", "tone": "warn"},
                {"p": "Sensor error and forward-model error add in quadrature, so the likelihood widens to admit how wrong the simulator is:"},
                {"expr": "σ = √(0.35² + model_σ²)  ·  model_σ = 1.30 from measured divergence"},
                {"p": "Sigma moves calibration, not ranking. Swept from 0.01 to 5.0, exact holds at 4.5% and top-5 at 30.3% while mean entropy travels 0.0 to 4.342 bits. Honest uncertainty costs nothing, so there is no accuracy argument for staying overconfident."}
            ]
        },
        {
            "mark": "0.226", "markUnit": "max bits per gauge", "heading": "Choosing the next gauge",
            "blocks": [
                {"p": "Each candidate probe is scored by the bits the posterior is expected to lose once that gauge is read. Information gain only survives an honest sigma:"},
                {"readout": {
                    "head": ["model σ", "EIG range across 8 gauges"],
                    "rows": [["0.5", "0.006 – 0.627 bits"],
                             ["1.3", "0.000 – 0.226 bits"],
                             ["2.5", "0.000 – 0.040 bits"]],
                    "mark": 1,
                    "caption": "At σ 2.5 no gauge carries information and max-infogain collapses into random. Sigma comes from measured divergence, never chosen defensively."
                }}
            ]
        },
        {
            "mark": "2", "markUnit": "probes at θ 0.50", "heading": "Knowing when to stop",
            "blocks": [
                {"p": "Every probe is a crew dispatched to a street, so the policy halts once the next probe buys fewer than θ bits, or the budget runs out. Replaying a decaying information sequence:"},
                {"readout": {
                    "head": ["threshold θ", "probes", "bits gained"],
                    "rows": [["0.50", "2", "1.81"],
                             ["0.15", "3", "1.99"],
                             ["0.05", "3", "1.99"],
                             ["0.00", "5", "2.04"],
                             ["fixed-3 arm", "3", "1.99"]],
                    "mark": 0,
                    "caption": "At θ 0.50 the policy keeps 91% of the information for two thirds of the probes."
                }},
                {"p": "This arm will not beat fixed-3 on accuracy and is not meant to. Its win is equal accuracy at lower cost, which is why probes spent is a first-class column everywhere in this product rather than a footnote."}
            ]
        },
        {
            "mark": "0.35", "markUnit": "psi noise floor", "heading": "Proving it is not circular",
            "blocks": [
                {"p": "If diagnosis merely inverts the simulator that produced the evidence, the result means nothing. The defence is that staging perturbs demands and roughness before observations are drawn, and that defence is only real if perturbed and nominal baselines diverge by more than the noise floor."},
                {"p": "So the gate measures per-gauge divergence between the two models and requires the median to clear 0.35 psi. It runs across the same seeds the evaluation uses and gates on the worst seed, not the mean, because a check that cannot fail is not a check."}
            ]
        }
    ]
};


glob RESULTS: dict = {
    "sheet": "Sheet 02 / Results",
    "title": ["Reported", "*as measured*"],
    "lede": "Every figure below came out of a run. Where an arm failed to beat its control, the row says so and stays in the table.",
    "meta": ["66 incidents per arm", "chance 4.5%", "model σ 1.30", "roughness CV 0.10"],
    "notes": [
        {
            "mark": "4", "markUnit": "arms, one control", "heading": "The four-arm table",
            "blocks": [
                {"p": "The random control is included because removing it would make every other row unreadable. Three of the four arms land on 1/22."},
                {"readout": {
                    "head": ["arm", "exact", "top 5", "hops", "probes"],
                    "rows": [["random control", "7.6%", "31.8%", "2.09", "3.0"],
                             ["max information gain", "4.5%", "27.3%", "2.18", "3.0"],
                             ["adaptive stopping", "4.5%", "22.7%", "2.18", "1.0"],
                             ["all 8 gauges", "4.5%", "30.3%", "2.18", "8.0"]],
                    "mark": 2,
                    "caption": "Chance on 22 junctions is 4.5%."
                }},
                {"callout": "The treatment arms did not beat the control in this regime. Random at 7.6% is noise above chance, not a win for randomness.", "tone": "warn"},
                {"p": "The diagnostic that explains it: reading all 8 gauges is no better than reading 3 at random. When more data stops helping, the forward model is misspecified rather than the policy being poor."}
            ]
        },
        {
            "mark": "3 → 1", "markUnit": "crew dispatches", "heading": "The result that did survive",
            "blocks": [
                {"p": "Adaptive stopping spent 1.0 probes against 3.0 while landing in the same accuracy band. In a regime where arms separate on accuracy that is the result worth having: comparable answers for a third of the callouts."},
                {"callout": "Each probe is a crew sent to a street. Cutting three dispatches to one is the claim Rivus makes, and it is the only claim here that survived measurement."}
            ]
        },
        {
            "mark": "0.04", "markUnit": "CV crossover", "heading": "The tension we did not hide",
            "blocks": [
                {"p": "The non-circularity gate and the accuracy pull against each other. Sweeping roughness perturbation strength, 66 incidents per row:"},
                {"readout": {
                    "head": ["roughness CV", "exact", "top 5", "median divergence", "gate pass"],
                    "rows": [["0.00", "40.9%", "80.3%", "0.341", "32%"],
                             ["0.02", "34.8%", "75.8%", "0.346", "36%"],
                             ["0.04", "13.6%", "45.5%", "0.490", "70%"],
                             ["0.06", "4.5%", "31.8%", "0.706", "100%"],
                             ["0.10", "4.5%", "30.3%", "1.294", "100%"]],
                    "mark": 2,
                    "caption": "The crossover near CV 0.04 is the defensible operating point: 13.6% exact, three times chance, gate passing 70% of the time."
                }},
                {"p": "The system beats chance only where the gate fails, and passes the gate only where the system stops working. Quoting the top rows while running the bottom ones would be the easiest way to lie with this table, so both columns stay."}
            ]
        },
        {
            "mark": "91", "markUnit": "% coverage at 90%", "heading": "Calibration",
            "blocks": [
                {"p": "The 90% credible set contains the true junction about 91% of the time. Sharper posteriors read better on a screen but under-cover, and an interval advertising 90% while delivering 56% is worse than publishing no interval at all."}
            ]
        }
    ]
};


glob LIMITS: dict = {
    "sheet": "Sheet 03 / Limits",
    "title": ["What Rivus", "*cannot* tell you"],
    "lede": "The failure modes are known and written down. If a claim is not on the results sheet, we are not making it.",
    "meta": ["one network", "arbitrary gauge set", "synthetic demo data"],
    "notes": [
        {
            "mark": "1 / 22", "markUnit": "exact-junction rate", "heading": "It does not find the pipe",
            "blocks": [
                {"callout": "Rivus does not identify the leaking pipe. Exact-junction accuracy sits at chance in the regime that passes the non-circularity gate, and any interface implying otherwise would contradict our own measurements.", "tone": "warn"},
                {"p": "What it does produce is a calibrated set and a cost. Those are the two things the interface is allowed to put on screen."}
            ]
        },
        {
            "mark": "8 ≈ 3", "markUnit": "gauges vs random",
            "heading": "The forward model is probably misspecified",
            "blocks": [
                {"p": "Reading all eight gauges performs no better than reading three chosen at random. That is the signature of a misspecified forward model rather than a weak probe policy: more information is not helping, so the map from leak to pressure is not close enough to reality for the extra readings to carry signal."},
                {"p": "Until that resolves, no policy should be expected to separate from the control on accuracy, and the roughness-CV question has to be settled first."}
            ]
        },
        {
            "mark": "n/3", "markUnit": "every third junction", "heading": "Gauge placement is arbitrary",
            "blocks": [
                {"p": "The gauge set is every third junction. That is not optimised and not drawn from any real deployment. Real placement would move every number reported here, so nothing on these sheets should be read as guidance on how many gauges a network needs or where they belong."}
            ]
        },
        {
            "mark": "n = 1", "markUnit": "networks tested", "heading": "One network, one topology",
            "blocks": [
                {"p": "Every result comes from a single 22-junction benchmark. Being a real published network beats a synthetic toy, but it is still one topology at one scale. Nothing here demonstrates that the behaviour holds at city scale, across different pipe-material mixes, or on networks with pumps and valves running on schedules."}
            ]
        },
        {
            "mark": "gpm", "markUnit": "leak model unit", "heading": "The leak model is a simplification",
            "blocks": [
                {"p": "Leaks are injected as added demand at a junction. Real leaks occur along pipes, vary with pressure, and change over time. Emitter-based modelling sits closer to the physics but saturates badly in this solver, so we took the tractable simplification and are naming it."}
            ]
        },
        {
            "mark": "fixture", "markUnit": "demo posteriors", "heading": "The demo data is synthetic",
            "blocks": [
                {"p": "On the live diagnosis screen the topology, coordinates, pipe connectivity and gauge positions are read straight from the real network file. The posteriors are synthetic, calibrated to match measured behaviour. That screen carries a Fixture badge for exactly this reason, and the badge clears itself once real evaluation output replaces the file."}
            ]
        },
        {
            "mark": "open", "markUnit": "what would settle it", "heading": "What would change our minds",
            "blocks": [
                {"p": "A forward model where adding gauges improves accuracy would remove the central objection. So would reproducing the crossover on a second network with real gauge placement. Until one of those lands, the defensible claim stays narrow: a calibrated credible set, and fewer crews sent to reach it."}
            ]
        }
    ]
};


def sheets() -> dict {
    """The three sheets, keyed by the route that renders each one.""";
    return {"method": METHOD, "results": RESULTS, "limits": LIMITS};
}


def emit(path: str) -> int {
    """Write the sheets where the site reads them, and report the byte count.""";
    os.makedirs(os.path.dirname(path), exist_ok=True);
    body = json.dumps(sheets(), indent=1, ensure_ascii=False);
    with open(path, "w", encoding="utf-8", newline="") as f { f.write(body); }
    return len(body);
}



glob SHEET_CSS: str = """
  :root{
    --ground:#00070F; --ink:#E8F4F8; --ink2:rgba(255,255,255,.60);
    --ink3:rgba(255,255,255,.35); --rule:rgba(255,255,255,.14);
    --belief:#2DD4BF; --critical:#FF7A8A; --foam:#BFE9FF;
    --mono:"SF Mono",ui-monospace,Menlo,Consolas,monospace;
    --disp:"Iowan Old Style",Georgia,"Times New Roman",serif;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  body{background:var(--ground);color:var(--ink);font-family:var(--mono);
       font-size:13px;-webkit-font-smoothing:antialiased;font-feature-settings:"tnum"}
  a{color:inherit}
  .wrap{max-width:1000px;margin:0 auto;padding:140px 24px 112px}
  .top{position:fixed;top:0;left:0;right:0;display:flex;align-items:center;gap:12px;
       padding:22px 32px;background:linear-gradient(#00070F,rgba(0,7,15,0));z-index:5}
  .glyph{width:17px;height:17px;position:relative}
  .glyph i{position:absolute;width:7px;height:7px;background:var(--belief)}
  .glyph i:nth-child(1){left:0;top:10px}
  .glyph i:nth-child(2){left:5px;top:5px;opacity:.75}
  .glyph i:nth-child(3){left:10px;top:0;opacity:.5}
  .brand{font-size:15px;text-decoration:none}
  .nav{margin-left:auto;display:flex;gap:24px;font-size:10px;text-transform:uppercase;
       letter-spacing:.12em;color:var(--ink3)}
  .nav a{text-decoration:none}
  .nav a:hover,.nav a.on{color:var(--belief)}
  .mast{display:grid;grid-template-columns:100px 1fr;gap:0 32px}
  .sheet{font-size:10px;text-transform:uppercase;letter-spacing:.2em;color:var(--belief);padding-top:12px}
  h1{font-family:var(--disp);font-weight:400;font-size:clamp(2.6rem,5vw,4rem);
     line-height:.95;letter-spacing:-.02em}
  h1 i{font-style:italic}
  .lede{font-size:13px;color:rgba(255,255,255,.55);line-height:1.75;margin-top:28px;max-width:54ch}
  .meta{margin-top:40px;padding-top:12px;border-top:1px solid var(--rule);
        display:grid;grid-template-columns:100px 1fr;gap:0 32px}
  .meta dl{display:flex;flex-wrap:wrap;gap:6px 32px;font-size:10px;text-transform:uppercase;
           letter-spacing:.14em;color:var(--ink3)}
  .notes{margin-top:56px}
  .note{display:grid;grid-template-columns:100px 1fr;gap:0 32px;padding:36px 0;
        border-top:1px solid rgba(255,255,255,.09)}
  .note:first-child{border-top:0;padding-top:0}
  .mark{text-align:right;padding-top:6px}
  .mark b{display:block;font-weight:400;font-size:15px;color:var(--belief);line-height:1}
  .mark s{display:block;text-decoration:none;font-size:9px;text-transform:uppercase;
          letter-spacing:.16em;color:var(--ink3);margin-top:6px;line-height:1.3}
  h2{font-family:var(--disp);font-weight:400;font-size:1.6rem;line-height:1.2;margin-bottom:16px}
  .body>*+*{margin-top:16px}
  .body p{font-size:13px;line-height:1.8;color:var(--ink2);max-width:62ch}
  .call{border-left:2px solid var(--belief);padding:4px 0 4px 20px;font-size:13px;
        line-height:1.8;color:rgba(255,255,255,.80)}
  .call.warn{border-color:var(--critical);color:rgba(255,122,138,.85)}
  .expr{font-size:13px;color:var(--foam);background:rgba(255,255,255,.03);
        border-top:1px solid rgba(255,255,255,.08);border-bottom:1px solid rgba(255,255,255,.08);
        padding:14px 20px}
  table{width:100%;border-collapse:collapse;font-size:12px;min-width:440px}
  th{font-weight:400;font-size:9px;text-transform:uppercase;letter-spacing:.16em;
     color:var(--ink3);padding:0 0 8px 12px;text-align:right}
  th:first-child{text-align:left}
  td{padding:10px 0 10px 12px;text-align:right;color:rgba(255,255,255,.65);
     border-top:1px solid rgba(255,255,255,.08)}
  td:first-child{text-align:left}
  tr.on td{color:var(--belief)}
  figcaption{font-size:11px;line-height:1.6;color:var(--ink3);margin-top:12px;padding-top:12px;
             border-top:1px solid rgba(255,255,255,.08)}
  .end{margin-top:80px;padding-top:20px;border-top:1px solid var(--rule);
       display:grid;grid-template-columns:100px 1fr;gap:0 32px}
  .end .k{font-size:10px;text-transform:uppercase;letter-spacing:.2em;color:rgba(255,255,255,.25)}
  .end .links{display:flex;flex-wrap:wrap;gap:8px 28px;font-size:12px}
  .end .links a{text-decoration:none;color:var(--ink3)}
  .end .links a:hover{color:rgba(255,255,255,.8)}
  .end .links a.live{color:var(--belief);border-bottom:1px solid rgba(45,212,191,.4);padding-bottom:2px}
  @media (max-width:760px){
    .mast,.meta,.note,.end{grid-template-columns:1fr}
    .mark{text-align:left;padding-bottom:14px}
  }
""";


def esc(s: str) -> str {
    """HTML-escape a fragment of prose.""";
    out = s.replace("&", "&amp;");
    out = out.replace("<", "&lt;");
    return out.replace(">", "&gt;");
}


def title_html(lines: list) -> str {
    """Asterisks mark the italic run; lines are separated by a rule break.""";
    parts = [];
    for line in lines {
        chunks = line.split("*");
        built = "";
        i = 0;
        for c in chunks {
            if i % 2 == 1 { built += "<i>" + esc(c) + "</i>"; } else { built += esc(c); }
            i += 1;
        }
        parts.append(built);
    }
    return "<br>".join(parts);
}


def block_html(b: dict) -> str {
    """One block: a readout table, an expression, a callout, or a paragraph.""";
    if "readout" in b {
        r = b["readout"];
        head = "";
        for h in r["head"] { head += "<th>" + esc(h) + "</th>"; }
        rows = "";
        i = 0;
        for row in r["rows"] {
            cells = "";
            for c in row { cells += "<td>" + esc(str(c)) + "</td>"; }
            on = "";
            if "mark" in r and r["mark"] == i { on = ' class="on"'; }
            rows += "<tr" + on + ">" + cells + "</tr>";
            i += 1;
        }
        cap = "";
        if "caption" in r { cap = "<figcaption>" + esc(r["caption"]) + "</figcaption>"; }
        return ('<figure><div style="overflow-x:auto"><table><thead><tr>' + head
                + "</tr></thead><tbody>" + rows + "</tbody></table></div>" + cap + "</figure>");
    }
    if "expr" in b { return '<p class="expr">' + esc(b["expr"]) + "</p>"; }
    if "callout" in b {
        warn = "";
        if b.get("tone", "") == "warn" { warn = " warn"; }
        return '<p class="call' + warn + '">' + esc(b["callout"]) + "</p>";
    }
    return "<p>" + esc(b["p"]) + "</p>";
}


def sheet_html(key: str, doc: dict) -> str {
    """One written sheet as a standalone page.""";
    meta = "";
    for m in doc["meta"] { meta += "<dd>" + esc(m) + "</dd>"; }

    notes = "";
    for n in doc["notes"] {
        body = "";
        for b in n["blocks"] { body += block_html(b); }
        notes += ('<section class="note"><div class="mark"><b>' + esc(n["mark"]) + "</b><s>"
                  + esc(n["markUnit"]) + '</s></div><div><h2>' + esc(n["heading"]) + "</h2>"
                  + '<div class="body">' + body + "</div></div></section>");
    }

    nav = "";
    for item in [["method", "Method"], ["results", "Results"], ["limits", "Limits"]] {
        on = "";
        if item[0] == key { on = ' class="on"'; }
        nav += '<a href="' + item[0] + '.html"' + on + ">" + item[1] + "</a>";
    }

    return ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
            + '<meta name="viewport" content="width=device-width,initial-scale=1">\n'
            + "<title>Rivus - " + esc(doc["sheet"]) + "</title>\n<style>" + SHEET_CSS
            + '</style>\n</head>\n<body>\n<div class="top">'
            + '<span class="glyph"><i></i><i></i><i></i></span>'
            + '<a class="brand" href="index.html">Rivus</a>'
            + '<nav class="nav">' + nav + '<a href="dashboard.html">Live board</a></nav></div>\n'
            + '<div class="wrap">\n<div class="mast"><div class="sheet">' + esc(doc["sheet"])
            + "</div><div><h1>" + title_html(doc["title"]) + "</h1>"
            + '<p class="lede">' + esc(doc["lede"]) + "</p></div></div>\n"
            + '<div class="meta"><div></div><dl>' + meta + "</dl></div>\n"
            + '<div class="notes">' + notes + "</div>\n"
            + '<div class="end"><div class="k">End</div><div class="links">'
            + '<a class="live" href="dashboard.html">Open the live diagnosis</a>'
            + '<a href="method.html">Method</a><a href="results.html">Results</a>'
            + '<a href="limits.html">Limits</a></div></div>\n</div>\n</body>\n</html>\n');
}


def emit_sheets(folder: str) -> int {
    """Write one page per sheet and report how many were written.""";
    n = 0;
    for (key, doc) in sheets().items() {
        with open(folder + "/" + key + ".html", "w", encoding="utf-8", newline="") as f {
            f.write(sheet_html(key, doc));
        }
        n += 1;
    }
    return n;
}

with entry:__main__ {
    n = emit("web/generated/docs.json");
    k = emit_sheets("web");
    print(f"[docs] web/generated/docs.json {n} chars, {k} sheets written to web/");
}
