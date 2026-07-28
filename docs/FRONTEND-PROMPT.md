# Rivus frontend build prompt

Paste everything below the line into a coding agent (Claude Code, Cursor, Codex).
It is written to be decision-complete: the implementer should have no open choices.

---

Build the demo frontend for **Rivus**, a water-distribution leak localization
system. It runs EPANET hydraulics over a real benchmark network, takes pressure
readings from a small set of gauges, and maintains a Bayesian posterior over which
junction is leaking. This frontend is the demo surface a reviewer sees.

## The single most important constraint

**This product does not find the exact pipe, and the UI must never imply that it
does.** Measured accuracy is at or near chance for exact-junction identification.
The honest and more interesting claim is: the system reports a calibrated credible
set, shows its own uncertainty in bits, and reaches comparable accuracy while
dispatching one crew instead of three. Build the UI around uncertainty and cost,
not around a triumphant pin drop.

Concretely this means:
- The posterior heatmap stays visibly diffuse. Do not add a "LEAK FOUND" state.
- Entropy in bits is a permanent, prominent readout that steps down per probe.
- Probes spent is a first-class counter, displayed with equal weight to accuracy.
- The true leak location is revealed only in a small, muted "ground truth" marker
  after playback ends, labeled as evaluation-only information.

## Stack

- Vite + React + TypeScript
- Tailwind CSS
- Hand-rolled inline SVG for the network. No d3-force, no Three.js, no charting library.
- No backend. No Next.js. No router. Single page.

The network has 22 junctions and 43 pipes. That is small. Do not reach for
graph-layout libraries; real X/Y coordinates come from the data file.

## Data contract

The app is a **pure replay player** over one static JSON file at
`public/replay.json`, loaded with `fetch` on mount. There is no live backend and
no API call. Type the file exactly as follows:

```ts
type Replay = {
  network: {
    junctions: { id: string; x: number; y: number }[];        // 22, the leak candidates
    sources: { id: string; x: number; y: number; kind: "reservoir" | "tank" }[];  // 3
    pipes: { id: string; from: string; to: string; flow: number }[]; // flow in gpm
    gauges: string[];        // junction ids that carry a pressure gauge
  };
  incidents: {
    id: string;
    trueLeakJunction: string;
    leakGpm: number;
    arms: Record<string, {          // e.g. "adaptive", "maxInfoGain", "randomControl", "allGauges"
      steps: {
        probeGauge: string | null;  // null on step 0, the prior
        readingPsi: number | null;  // null on step 0
        eigBits: number | null;     // expected information gain of this probe
        posterior: Record<string, number>;  // junction id -> probability, sums to 1
        entropyBits: number;
        credibleSet: string[];      // junction ids in the 90% credible set
      }[];
      probesUsed: number;
      exactHit: boolean;
      top5Hit: boolean;
    }>;
  }[];
  summary: {
    arms: {
      name: string;
      exactPct: number;
      top5Pct: number;
      meanHops: number;
      meanProbes: number;
    }[];
    chancePct: number;   // 4.5 for a 22-junction network
    nIncidents: number;
  };
};
```

Step 0 is always the uniform prior with `probeGauge: null` and
`entropyBits: log2(22) = 4.459`.

**Before real data exists**, write `scripts/make-fixture.ts` that generates a
plausible `public/replay.json`: read node coordinates and pipe endpoints from
`temp.inp` (the `[COORDINATES]` and `[PIPES]` sections, both present and
populated), classify each node using the `[JUNCTIONS]`, `[RESERVOIRS]` and
`[TANKS]` id lists, then synthesize posteriors that sharpen realistically over
three probes. Assert 22 junctions, 3 sources and 43 pipes and fail loudly if the
parse does not produce exactly those counts. Render a small persistent badge reading `FIXTURE DATA` whenever
`replay.json` was fixture-generated, driven by a `"fixture": true` flag at the
root of the file. Real evaluation output replaces the file later with no code
changes.

## Layout

Single full-viewport screen, three regions, no scrolling:

1. **Left rail, ~280px.** Incident selector, arm selector (four arms as radio
   pills), transport controls (play, step forward, reset), playback speed.
2. **Center, flex-1.** The network SVG. This is the hero and gets the most space.
3. **Right rail, ~320px.** Live readouts stacked vertically:
   - Entropy in bits, large, monospace, tabular figures, with a small sparkline
     of its history across the current run.
   - Probes spent, large, monospace, with "crew dispatches" as the sublabel.
   - Credible set: the junction ids currently in the 90% set, as chips, count shown.
   - Last probe: gauge id, reading in psi, EIG in bits.
   - Below a divider, the four-arm summary table from `summary.arms`, with the
     chance line drawn in so a reader can see what beating chance would look like.

## The network SVG

Normalize the raw EPANET coordinates into a viewBox with ~5% padding. Y axis must
be flipped, since EPANET coordinates are mathematical (Y up) and SVG is Y down.

**Node taxonomy, verified against the file. Get this wrong and pipes vanish.**
`[COORDINATES]` contains 25 rows, not 22: the 22 junctions plus one reservoir
(id `40`) and two tanks (ids `41`, `42`). Two pipes, `142` and `143`, connect
junctions `21` and `22` to tanks `41` and `42`. If you build the coordinate
lookup from `[JUNCTIONS]` alone, those two pipes silently fail to render and you
will see 41 pipes instead of 43. Build the lookup from all node types, but keep
the posterior, the heatmap and the credible set over the 22 junctions only, since
a tank is not a leak candidate.

- **Pipes** are `<path>` or `<line>` elements, stroke width 2, base color the
  muted slate line color.
- **Junctions** are circles, radius 5.
- **Sources** (reservoir and tanks) render as small squares, side 10, in the
  secondary text color with no fill, never heat-mapped and never in the credible
  set. Label each with its id.
- **Gauge junctions** get a distinct ring: an outer stroked circle at radius 9,
  1px, in the accent cyan, so it is obvious which nodes can be read.
- **Posterior heatmap** maps each junction's probability to fill color and radius.
  Interpolate fill from the background slate to the cyan accent across the
  probability range, normalized to the current step's max so the map never goes
  flat and unreadable. Radius scales 5 to 14.
- **Credible set members** get a thin dashed outline so set membership is legible
  independently of the color ramp.
- **Ground truth marker** is a small hollow square outline in muted amber, shown
  only after playback completes, with a tiny label reading `ground truth
  (evaluation only)`.

## Water motion, which is the visual identity

Water motion must encode data, not decorate. Three uses, in priority order:

1. **Flowing pipes.** Every pipe path gets `stroke-dasharray: 6 10` and a CSS
   keyframe animating `stroke-dashoffset` from `0` to `-16`, running linear and
   infinite. Set `animation-duration` per pipe as an inline style, inversely
   proportional to `Math.abs(flow)`, clamped to the range `0.8s` to `6s`. High
   flow visibly moves faster. Respect `prefers-reduced-motion: reduce` by setting
   `animation: none`.

2. **Posterior ripple.** Each junction whose probability exceeds 5% emits an
   expanding ring: a circle animating radius outward and opacity to zero over
   2.4s, infinite, with `animation-delay` staggered by index so rings do not
   pulse in lockstep. Ring opacity peak scales with that junction's probability,
   so the strongest visual pulse is literally the strongest belief. Cap at the
   top 6 junctions to keep it legible.

3. **Decorative wave field, hero and idle only.** Two or three layered SVG sine
   paths translating on X at different speeds (18s, 26s, 34s) and opacities
   (0.10, 0.07, 0.05), used behind the title card and behind the empty state
   before an incident is selected. **Do not render these behind the network
   view.** The heatmap needs a quiet background and waves there destroy
   legibility exactly where the science is.

Do not use a WebGL or Three.js water shader. Do not add a global animated gradient.

## Motion rules for everything else

- UI transitions are 150ms to 250ms. Nothing over 300ms.
- Never `ease-in`. Use `cubic-bezier(0.32, 0.72, 0, 1)` for entries and movement,
  `cubic-bezier(0.4, 0, 1, 1)` only for exits.
- Buttons take `scale(0.97)` on `:active`.
- Nothing enters from `scale(0)`. Entry starts at `scale(0.96)` and `opacity: 0`.
- Posterior changes between steps animate the fill and radius over 220ms so the
  belief update is visible as motion, not as a jump cut.
- Only animate `transform` and `opacity`, plus the SVG attributes named above.

## Visual direction

Dark, instrument-panel, engineering. This reads well on a projector and lets the
flow animation glow.

- Background `#0B1015`, panel surface `#121A21`, hairline borders `#1E2A33`.
- Primary text `#E4ECF2`, secondary `#8A9BA8`.
- Water and flow accent: cyan `#2DD4BF` through `#22A5C4`.
- Probes and cost accent: amber `#E0A458`. Cost is a different semantic axis from
  belief, so it must not share the cyan.
- Ground truth marker: muted amber `#A8794A`, low contrast on purpose.
- No purple. No violet-to-pink gradient. No glassmorphism. No card inside a card
  inside a card.

Type: **IBM Plex Sans** for prose and labels, **IBM Plex Mono** for every number,
junction id, gauge id, and table cell. Load both from Google Fonts. All numeric
readouts use `font-variant-numeric: tabular-nums` so the entropy counter does not
jitter as it ticks down. Section labels are 11px, uppercase, letter-spacing
0.08em, in the secondary text color.

## Acceptance criteria

Do not report the build as done until you have run `npm run dev`, opened the page,
and confirmed each of these by looking at it:

1. The network renders 22 junctions, 3 sources and **43** pipes at their real
   coordinates, right way up. Count the rendered pipe elements in the DOM. If you
   see 41, you dropped the two tank-connected pipes described above.
2. Pipe dashes visibly flow, and high-flow pipes are visibly faster than low-flow ones.
3. Pressing play advances the probe sequence; the heatmap redistributes, the
   entropy number decreases, and the probes counter increments.
4. Switching arms changes the number of probes spent, and the adaptive arm
   visibly spends fewer than the fixed arms.
5. The summary table renders all four arms including the random control, with the
   chance line visible.
6. Nothing anywhere in the UI asserts that a specific pipe or junction is the leak.
7. The page does not scroll and does not overflow horizontally at 1440x900.

State plainly which criteria you verified by observation and which you did not.
