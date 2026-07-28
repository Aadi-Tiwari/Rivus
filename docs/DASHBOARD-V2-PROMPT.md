# Rivus dashboard v2 build prompt

Paste everything below the line into a coding agent (Claude Code, Cursor, Codex).
It is written to be decision-complete: the implementer should have no open choices.

The existing `FRONTEND-PROMPT.md` built v1. This document supersedes it for the
dashboard route only. Where the two disagree, this one wins.

---

Rebuild the Rivus dashboard **in place** at `web/components/dashboard.tsx`. The
route `app/dashboard/page.tsx` stays as it is. Do not touch the landing page,
the hero, the GL particle field, or the `/method`, `/results`, `/limits` pages.

Rivus runs EPANET hydraulics over a real benchmark water network, reads pressure
from a small set of gauges, and maintains a Bayesian posterior over which
junction is leaking. The current dashboard replays one incident at a time. The
new one is an **operations console**: a queue of open incidents, and a case view
that opens from a row.

## The brief in one line

Someone should want to keep looking at this screen.

The v1 dashboard is information-correct and visually dead. That is the problem
being fixed. Every section below exists to serve appearance and feel first, and
correctness second. Correctness is still non-negotiable, it is just no longer the
thing that gets all the attention.

## Why v1 looks bad, mechanically

Do not re-derive these mistakes. They are all present in the file you are
replacing and they are all measurable:

1. Nearly every label is `text-[10px]` at `text-white/40`, `/35`, `/30`, `/25`.
   Half the interface is barely visible on purpose.
2. Borders are `border-white/[0.08]` hairlines. Panels do not read as objects.
3. There is no type scale. A section label and a body value differ by 2px.
4. Five panels of roughly equal visual weight, so nothing is the subject.
5. Data bars are 1.5px tall.
6. The honesty rules ("no LEAK FOUND", "credible sets, not single pipes") were
   applied as *visual* restraint, which is a category error.

**Rule: the honesty constraint is a content rule. It restricts what you may
claim. It never justifies grey text, small type, or a timid layout.** A
calibrated credible set can be presented with total visual confidence.

## Reference and anti-reference

`rivus-dash2.png` (in `C:\Users\tiwar\`) is the target for *scale contrast,
breathing room, and legible color*: large display numerals, real padding,
readable status chips, panels that read as surfaces.

It is also a stock admin template, and that half is banned. Specifically do not
build: a left sidebar of nav links, Settings / Support / Sign out, a user avatar
chip, a search input, a notification bell, or a four-up row of unrelated KPI
cards. None of those have a function in this product.

## Layout

Full viewport, `h-svh`, no page scroll, no horizontal overflow. Design at
1440x900 and confirm at 1280x800. Three columns, fixed geometry, `gap-4`,
outer padding `p-4`.

```
+----------------------------------------------------------------------------+
| command strip   72px tall, full width                                       |
+-------------------+---------------------------------------+----------------+
|                   |                                       |                |
|  INCIDENT QUEUE   |          NETWORK STAGE                |   READOUT RAIL |
|  320px fixed      |          flex-1, the subject          |   360px fixed  |
|                   |                                       |                |
|  8 rows           |          the map never unmounts       |   swaps content|
|                   |                                       |   by state     |
|                   |  +---------------------------------+  |                |
|                   |  | transport dock, floats over map |  |                |
|                   |  +---------------------------------+  |                |
+-------------------+---------------------------------------+----------------+
```

The console has exactly two states and they share this shell:

- **At rest.** No incident selected. The map shows the whole network breathing,
  gauges ringed, no heat. The rail shows program-level results (the 66-incident
  arm comparison). The queue is the call to action.
- **Case open.** An incident is selected. The map keeps its position and the
  posterior heat blooms into it. The rail swaps to live readouts. The transport
  dock fades up over the map.

**The map never unmounts and never gets replaced by a screen transition.** This
is the single most important structural decision in the document. Selecting a
row animates the same SVG rather than swapping views. That continuity is most of
what makes the thing feel alive rather than like a page of tables.

### Command strip (72px)

Left: the Rivus logo, linking home. Then a hairline divider, then the current
state as one line of display type: at rest `8 open incidents`, with a case open
`INC-003 · Kingsway` where the second part is the district label.

Right: the four policy arms as a segmented control (not four separate buttons in
a row: one track, one sliding indicator that animates between segments), then the
`FIXTURE` badge. Playback controls do **not** live here, they live on the dock.

### Incident queue (320px)

Header: eyebrow label `OPEN INCIDENTS`, then the count in display numerals.

Eight rows, one per incident in `replay.json`. Each row is a single button and
the primary interactive object on the screen, so it gets real height (roughly
84px) and real padding, not a table line. Per row:

- Incident id in mono, 13px, full opacity.
- District label in 12px secondary. See the district rule below.
- The **credible set size** as the row's display number, 28px tabular mono,
  rendered as `6/22`. This is the row's headline because it varies genuinely
  across the data (5 to 15) and it is the actual product output.
- A slim entropy bar: current entropy against the 4.46 bit prior, filled in
  cyan, with a hairline tick at the prior so the shrink is legible.
- A status chip. See the status rule below.

Row states: rest, hover (surface lifts one elevation step, 150ms), selected
(cyan left edge 2px, surface lifted, chip brightened). Selected must be readable
from across a room. Stagger the rows in by 30ms each on first mount.

### Network stage (flex-1)

The hero. It gets the most pixels and the least clutter. Inside it:

- The network SVG, filling the region, centered, with roughly 6% padding.
- A single line of caption type at the top left in Sentient, 24px or larger:
  at rest `What we know, and what we don't`, with a case open the incident's
  own line. Sentient only ships Extralight 200 and Light Italic 300 in this
  repo, so it is illegible below about 22px. Never use it for labels or data.
- Bottom right, a compact legend. Five entries, 12px, each with its mark.
- Bottom center, the **transport dock**: a floating pill, elevated surface, with
  play/pause, step forward, reset, and the step pips. It fades and lifts in over
  200ms when a case opens. This is the only element allowed to overlap the map.

### Readout rail (360px)

At rest, top to bottom:

1. `MEASURED OVER 66 INCIDENTS` panel. The four arms plus the chance line,
   compared on top-5 accuracy and mean crew dispatches. Arms are rows with a
   proportional cyan track for accuracy and an amber pip count for dispatches,
   so the two axes never share an encoding. The chance line at 4.5% is drawn
   into the same scale as a dashed vertical rule, not as a fifth row.
2. `WHAT WE CANNOT SAY` panel. Three sentences of 14px prose stating that exact
   junction identification sits at chance, that the product is the credible set
   and the dispatch count, and that no policy beat the control on accuracy.
   Prose, at readable size, is a design element here. Do not shrink it.

With a case open, top to bottom:

1. **Uncertainty**, the largest number on the rail: entropy in bits at 48px
   tabular mono, cyan, with the delta from the prior beneath it in 13px, and the
   per-step sparkline of the run.
2. **Dispatches**, second largest: 40px tabular mono in amber, `1 of 3`, with
   the pip row beneath and the sublabel `crews sent to a street`.
3. **Leading candidates**: six rows, junction id, bar, percentage. Bars are 6px
   tall minimum with a chance tick drawn in. Hovering a row highlights that node
   on the map and vice versa. This two-way link is required.
4. **Probe log**: one line per step, gauge id, reading in psi, bits gained. New
   lines enter with a 180ms fade and 4px rise.

## Type

Two families, both already loaded. Do not add a third.

- **Geist Mono** (`var(--font-geist-mono)`) for every number, id, label, chip
  and table cell. All numeric readouts get `font-variant-numeric: tabular-nums`.
- **Sentient** (`font-sentient`) for the map caption and panel titles at 22px
  and above only.

Scale, and these are floors, not suggestions:

| tier | size | use |
| --- | --- | --- |
| hero numeral | 48px | entropy in the case rail |
| display numeral | 40px | dispatches, queue count |
| row numeral | 28px | credible set size per queue row |
| title | 22px | panel titles, map caption |
| body | 14px | prose, secondary values |
| data | 13px | ids, readings, log lines |
| eyebrow | 11px, uppercase, 0.14em tracking | section labels only |

**Nothing renders below 11px. The 11px tier is reserved for uppercase section
eyebrows and nothing else.** There must be at least a 4x jump between the hero
numeral and the eyebrow tier.

## Color and opacity

Ground `#00070F`. Panel `#071620`. Elevated surface `#0C2029`. Borders `#1B3440`
at rest and `#2A5568` on hover, which is a visible hairline rather than the
invisible one v1 used.

Text: primary `#E8F4F8` at full opacity, secondary `#93B0BC`, and that is the
floor. **No text that carries meaning may be rendered below 70% effective
opacity. Delete every `/40`, `/35`, `/30` and `/25` text class from the old
file.** Opacity below that is for decorative rules and dividers only.

Two semantic axes, and they may not be used for anything else:

- **Belief** is cyan: `--belief #2DD4BF`, `--belief-deep #22A5C4`, `--foam #BFE9FF`.
- **Cost** is amber: **change `--cost` in `app/globals.css` from `#7AA2FF` to
  `#E8A33D`, and delete the "there is deliberately no yellow anywhere in this
  system" comment above it.** The periwinkle currently in the file sits inside
  the cyan family and cannot carry a second axis. Cost is a different kind of
  quantity from belief and must look like one. This is a deliberate, recorded
  change to the design system, not a drift.

`--critical #FF7A8A` and `--ok #5BE0A6` stay for status only.

Banned outright: purple, violet, indigo, any violet-to-pink gradient,
glassmorphism or `backdrop-blur` anywhere over the map, a card inside a card
inside a card, tinted rounded squares behind icons, emoji, and drop shadows used
as decoration. Glow is permitted only where it encodes belief mass.

## Depth and texture

Three elevation steps only: ground, panel, elevated. Differentiate them with
surface value and border, not with shadow.

The ground layer gets two things and no more: one very large radial gradient
from `#062430` at roughly 20% opacity centered behind the map, and a static SVG
noise or grain overlay at 2.5% opacity across the whole viewport. Both are
static. Neither animates. Together they stop the black from reading as flat
nothing, which is a large part of why v1 looks cheap on a projector.

Do not put the WebGL particle field on this route. The heat map needs a quiet
background.

## Motion

"Entertaining" here means: something is always alive, state changes read as
motion rather than jump cuts, and numbers move. It does not mean bounce easing,
parallax, or a global animated gradient.

Always alive:

- **Flow dashes.** Every pipe carries `stroke-dasharray: 6 10` and animates
  `stroke-dashoffset` to `-16`, linear, infinite. Duration is inversely
  proportional to `Math.abs(flow)`, clamped 0.8s to 6s, set inline per pipe.
  High-flow mains visibly move faster. Carry this forward from v1, it works.
- **Posterior ripple.** Junctions above 5% belief emit an expanding ring, 2.4s,
  infinite, staggered by index, peak opacity scaled by probability. Cap at the
  top six so it stays legible.

On state change:

- **Numerals count.** Entropy, dispatches, credible set size and percentages
  animate from their old value to their new one over 400ms with an
  `requestAnimationFrame` interpolation, not a CSS transition on text. This is
  the highest-leverage single change in this document for making the console
  feel alive. Keep `tabular-nums` on so nothing reflows while counting.
- **Posterior update**: node fill and radius transition over 220ms.
- **Case open**: the map recenters and scales toward the incident's active
  region over 420ms, the heat blooms in, the rail content cross-fades, the dock
  lifts in. All of it concurrent, one gesture.
- **Rail swap**: outgoing content 120ms fade out, incoming 200ms fade and 6px
  rise, with a 60ms overlap.

Rules, all of them carried forward from v1 and still correct:

- UI transitions 150ms to 250ms. Only the map camera (420ms) and the numeral
  counters (400ms) may exceed 300ms.
- Never `ease-in`. Entries and movement use `cubic-bezier(0.32, 0.72, 0, 1)`.
  Exits use `cubic-bezier(0.4, 0, 1, 1)`.
- Buttons take `scale(0.97)` on `:active`.
- Nothing enters from `scale(0)`. Entry begins at `scale(0.96)`, `opacity: 0`.
- Animate `transform` and `opacity` only, plus the named SVG attributes.
- Under `prefers-reduced-motion: reduce`, kill flow, ripple and the map camera
  move, and snap numerals to their final value instead of counting.

## Data honesty

Every number on the screen must be derivable from `public/replay.json`. The file
carries `"fixture": true`, so the `FIXTURE` badge stays visible. Beyond that:

- **District labels are cosmetic and must be derived from the incident index**,
  from a fixed eight-entry name table. **Never derive a district from
  `trueLeakJunction`.** That field is the answer, and leaking it into a label
  before playback ends would reveal ground truth in the queue.
- **Status is session state, not a claim about the world.** Map it exactly:
  never opened is `unprobed`, partially played is `diagnosing`, playback
  finished is `narrowed`. The words `resolved`, `located`, `found` and `fixed`
  must not appear anywhere in the interface.
- **Do not build a "water at risk" tile.** All eight incidents are 400 gpm, so
  the sum is a constant and a constant presented as a live metric is a lie with
  extra steps. The fields that genuinely vary and are worth showing are credible
  set size (5 to 15), entropy (1.96 to 3.93 bits), leading belief (0.198 to
  0.657) and dispatches (1, 3, 3, 8 by arm).
- Do not invent incidents. There are exactly eight and they are listed in
  Appendix B. Do not pad the queue to fill space.
- Ground truth appears only after playback completes, as a small hollow marker
  in muted slate, labeled `ground truth (eval only)`.
- Nothing in the interface may assert that a specific junction is the leak.

## Interaction

- Click a queue row to open the case. Click the open row again, or press `Esc`,
  to return to rest.
- `Space` plays and pauses. `ArrowRight` steps forward. `R` resets.
- `1` through `8` select the corresponding incident.
- Hovering a candidate row in the rail highlights that node on the map, and
  hovering a node highlights the rail row. Both directions.
- Hovering a map node shows a compact tooltip: junction id and belief percent,
  in 13px mono on an elevated surface.

## Acceptance criteria

Do not report this build as done until you have run `npm run dev`, opened the
page, and confirmed each item by looking at it. Screenshot both states at
1440x900 using the Playwright MCP and attach them.

1. The map renders 22 junctions, 3 sources and **43** pipes at their real
   coordinates, right way up. Count the rendered pipe elements. 41 means you
   built the coordinate lookup from `[JUNCTIONS]` alone, see Appendix C.
2. Pipe dashes visibly flow and high-flow pipes are visibly faster.
3. Opening an incident animates the existing map. The map element is never
   unmounted and remounted, and there is no page-level transition.
4. Entropy, dispatches and credible set size visibly count between values rather
   than snapping.
5. Grep the finished file for `text-[10px]`, `text-[9px]`, `/40`, `/35`, `/30`
   and `/25` on text elements. Every hit must be gone or justified in a comment.
6. The four-arm comparison renders with the chance line at 4.5% visible on the
   same scale.
7. Nothing anywhere asserts that a specific junction or pipe is the leak, and
   the words resolved, located, found and fixed do not appear.
8. No page scroll and no horizontal overflow at 1440x900 and at 1280x800.
9. `prefers-reduced-motion: reduce` stops flow, ripple and counting.

State plainly which criteria you verified by observation and which you did not.

---

## Appendix A: data contract

`public/replay.json`, fetched on mount. No backend, no API.

```ts
type Replay = {
  fixture?: boolean;
  network: {
    junctions: { id: string; x: number; y: number }[];   // 22, the leak candidates
    sources: { id: string; x: number; y: number; kind: "reservoir" | "tank" }[]; // 3
    pipes: { id: string; from: string; to: string; flow: number }[];  // 43, flow in gpm
    gauges: string[];    // 8 junction ids: 1,4,7,10,13,16,19,22
  };
  incidents: {
    id: string;
    trueLeakJunction: string;   // evaluation only, never surfaced before playback ends
    leakGpm: number;
    arms: Record<"adaptive" | "maxInfoGain" | "randomControl" | "allGauges", {
      steps: {
        probeGauge: string | null;   // null on step 0, the prior
        readingPsi: number | null;
        eigBits: number | null;
        posterior: Record<string, number>;  // junction id -> probability, sums to 1
        entropyBits: number;
        credibleSet: string[];       // ids in the 90% credible set
      }[];
      probesUsed: number;
      exactHit: boolean;
      top5Hit: boolean;
    }>;
  }[];
  summary: {
    nIncidents: 66;
    chancePct: 4.5;
    noisePsi: 0.35;
    arms: { name: string; key: string; exactPct: number; top5Pct: number;
            meanHops: number; meanProbes: number }[];
  };
};
```

Step 0 is always the uniform prior, `probeGauge: null`, `entropyBits` 4.459.

Measured summary, to be rendered as is: random control 31.8% top-5 over 3 probes,
max information gain 27.3% over 3, adaptive stopping 22.7% over 1, all 8 gauges
30.3% over 8. Chance is 4.5%. No policy beat the control on accuracy, and
adaptive stopping matched them on a third of the dispatches. That is the result,
reported as measured.

## Appendix B: the eight incidents

Credible set size and entropy below are at the end of the adaptive run, which is
what the queue rows show by default. They change with the selected arm.

| id | leak gpm | adaptive end entropy | adaptive credible set |
| --- | --- | --- | --- |
| INC-001 | 400 | 3.60 | 13/22 |
| INC-002 | 400 | 2.85 | 9/22 |
| INC-003 | 400 | 2.30 | 6/22 |
| INC-004 | 400 | 3.55 | 12/22 |
| INC-005 | 400 | 3.38 | 12/22 |
| INC-006 | 400 | 3.45 | 12/22 |
| INC-007 | 400 | 3.09 | 10/22 |
| INC-008 | 400 | 3.41 | 12/22 |

District names are cosmetic labels keyed to this order. Use: Harbour West,
Old Mill, Kingsway, Riverside, North Quay, Ashgrove, Fenwick, Salt Marsh.

## Appendix C: the network SVG, and the trap

Normalize the raw EPANET coordinates into a viewBox that takes the network's own
aspect ratio, with about 6% padding. **Flip the Y axis**: EPANET coordinates are
Y-up, SVG is Y-down.

`[COORDINATES]` in `temp.inp` contains 25 rows, not 22: the 22 junctions plus
reservoir `40` and tanks `41` and `42`. Pipes `142` and `143` connect junctions
`21` and `22` to the two tanks. Build the position lookup from **all** node
types. Building it from `[JUNCTIONS]` alone makes those two pipes silently fail
to render and you will count 41 pipes instead of 43. Keep the posterior, the
heat map and the credible set over the 22 junctions only, since a tank is not a
leak candidate.

Marks:

- **Pipes**: a single static under-path for the mains at `#25505F`, 2px, plus
  per-pipe animated dashed lines at `#3D7C94`, 2px, for the flow.
- **Junctions**: circles, radius 5 at chance, growing to 14 at full heat.
- **Heat**: map probability to fill and radius on a **fixed** scale, from chance
  (1/22) to a 0.5 ceiling. Never normalize to the current maximum, which makes a
  flat prior look like total confidence and an 8% leader look like a 60% one.
- **Sources**: 12px hollow squares in `#8FA6B4`, labeled, never heat mapped.
- **Gauges**: an outer ring in cyan at 45% opacity so it is obvious which nodes
  can be read.
- **Credible set members**: a dashed outline in foam, so membership is legible
  independently of the color ramp.
- **Probed now**: a 2px amber ring.

No d3, no force layout, no charting library, no WebGL water shader. The network
has 22 nodes and real coordinates. Hand-rolled inline SVG only.
