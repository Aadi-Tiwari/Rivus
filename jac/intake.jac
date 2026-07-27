"""PipeTrace — field intake.

The only place in this system where a language model is allowed to run, and the only
thing it is allowed to do: turn a crew's free-text radio note into typed fields.

A foreman says "hydrant by the school on Elm reads 41 psi, valve V7 is seized". That is
unstructured text, which is genuinely what models are good at. What the leak is, where
to measure next, and whether a valve plan is safe are all decided by EPANET and Bayes in
simulate.jac and graphops.jac. Nothing here touches those.

If no model is configured, intake falls back to a deterministic parser and says so out
loud. It never guesses a pressure reading, because a fabricated reading would flow
straight into the posterior and corrupt every number downstream.
"""

include network;

import re;
import from byllm.llm { Model }

glob NOTE_MODEL = Model(model_name="gpt-4o-mini");
glob LLM_AVAILABLE: dict = {"ok": True, "why": ""};


obj FieldNote {
    has location: str;          # junction id the crew is standing at, "" if unclear
    has reading_psi: float;     # gauge reading in psi
    has has_reading: bool;      # False when the note carries no number at all
    has issue: str;             # e.g. "valve seized", "" when nothing reported
    has confidence: float;      # 0..1, how sure the parse is
}


"""Read a water crew's field note and extract the junction they are reporting from, the
pressure in psi if they gave one, and any equipment problem they mention. The junction
must be one of the known ids. If the note gives no numeric pressure, set has_reading to
false and leave reading_psi at 0.0 — never estimate a value."""
def parse_note_llm(note: str, known_nodes: list) -> FieldNote by NOTE_MODEL();


def parse_note_fallback(note: str, known_nodes: list) -> FieldNote {
    """Deterministic parse: pull the first psi figure and the first known junction id.

    This is the path taken when no model is configured. It is strict on purpose — if it
    cannot find a number it reports has_reading=False rather than inventing one.""";
    psi = 0.0;
    got = False;
    m = re.search(r"(-?\d+(?:\.\d+)?)\s*(?:psi|PSI)", note);
    if m { psi = float(m.group(1)); got = True; }

    # Strip the pressure figure before hunting for a junction id, and refuse to match
    # a digit that sits inside a larger number. Without this, "38.5 PSI" yields node 5,
    # because '.' counts as a word boundary — a silently wrong reading is far worse
    # than no reading at all.
    hay = note;
    if m { hay = note[:m.start()] + " " + note[m.end():]; }

    loc = "";
    best = -1;
    for n in known_nodes {
        hit = re.search(r"(?<![\d.])" + re.escape(n) + r"(?![\d.])", hay);
        if hit {
            # prefer an id that is explicitly labelled over a bare number
            score = 1;
            if re.search(r"(?:node|junction|jct|at)\s+" + re.escape(n)
                         + r"(?![\d.])", hay, re.I) { score = 2; }
            if score > best { best = score; loc = n; }
        }
    }

    issue = "";
    low = note.lower();
    for word in ["seized", "stuck", "buried", "inaccessible", "broken", "missing"] {
        if word in low { issue = word; break; }
    }
    conf = 0.35;
    if got and loc != "" { conf = 0.7; }
    return FieldNote(location=loc, reading_psi=psi, has_reading=got,
                     issue=issue, confidence=conf);
}


def parse_note(note: str, known_nodes: list) -> FieldNote {
    """Try the model, fall back to the deterministic parser, and never fail silently.""";
    if LLM_AVAILABLE["ok"] {
        try {
            return parse_note_llm(note, known_nodes);
        } except Exception as e {
            LLM_AVAILABLE["ok"] = False;
            LLM_AVAILABLE["why"] = str(e)[:90];
            print(f"  [intake] no model available ({LLM_AVAILABLE['why']})");
            print(f"  [intake] FALLING BACK to the deterministic parser — "
                  f"readings below are regex-extracted, not model-inferred");
        }
    }
    return parse_note_fallback(note, known_nodes);
}


walker IngestNote {
    """Turns one radio note into a typed Observation node on the graph."""
    has note: str;
    has parsed: FieldNote = None;
    has accepted: bool = False;
    has reason: str = "";

    can take with entry {
        known = [];
        for j in of_type([-->], Junction) { known.append(j.name); }
        self.parsed = parse_note(self.note, known);

        if self.parsed.location == "" {
            self.reason = "no known junction named in the note";
        } elif not self.parsed.has_reading {
            self.reason = "note carries no pressure reading";
        } else {
            self.accepted = True;
            self.reason = "typed and attached to the graph";
            here ++> Observation(step=0, location=self.parsed.location,
                                 reading_psi=self.parsed.reading_psi,
                                 info_bits=0.0, travel_min=0.0,
                                 survivors=0, entropy_bits=0.0);
        }
        if self.parsed.issue != "" {
            here ++> Finding(kind="field", verdict="NOTED",
                             detail=f"crew reports {self.parsed.issue} at "
                                    f"{self.parsed.location}");
        }
    }
}
