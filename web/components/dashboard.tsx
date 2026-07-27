"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { Logo } from "./logo";
import { ParticleBackground } from "./particle-background";
// Aliased: an unaliased `Map` import shadows the global Map constructor used below.
import { Map as MapIcon, Pause, Play, RotateCcw, SkipForward } from "lucide-react";

type Node = { id: string; x: number; y: number };
type Source = Node & { kind: "reservoir" | "tank" };
type Pipe = { id: string; from: string; to: string; flow: number };
type Step = {
  probeGauge: string | null;
  readingPsi: number | null;
  eigBits: number | null;
  posterior: Record<string, number>;
  entropyBits: number;
  credibleSet: string[];
};
type Arm = { steps: Step[]; probesUsed: number; exactHit: boolean; top5Hit: boolean };
type Replay = {
  fixture?: boolean;
  network: { junctions: Node[]; sources: Source[]; pipes: Pipe[]; gauges: string[] };
  incidents: { id: string; trueLeakJunction: string; leakGpm: number; arms: Record<string, Arm> }[];
  summary: {
    nIncidents: number;
    chancePct: number;
    noisePsi: number;
    note?: string;
    winner?: string;
    arms: { name: string; key: string; exactPct: number; top5Pct: number; meanHops: number; meanProbes: number }[];
  };
};

const VIEW = 1000;
const PAD = 0.07;
const EASE = "cubic-bezier(0.32, 0.72, 0, 1)";
// Frosted glass over the particle field: surfaces sit at 50% so the field reads
// through them. The wide blur is what keeps text legible over moving particles, so
// it stays even at this transparency.
const PANEL =
  "backdrop-blur-md bg-[#08161F]/35 border border-white/[0.20] rounded-2xl shadow-[0_10px_40px_-16px_rgba(0,0,0,0.7)]";
const WELL = "rounded-xl border border-white/10 bg-[#020A11]/35 overflow-hidden";
// Belief that earns a fully saturated node. Fixed, so heat means the same thing in
// every frame instead of being relative to whatever the current leader happens to be.
const FULL_HEAT = 0.5;

// Arm names arrive from the data file in lower case. Capitalise at the edge so the
// interface reads as written English without editing the evaluation output.
const sentenceCase = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

const Label = ({ children }: { children: React.ReactNode }) => (
  <div className="font-mono text-[10px] uppercase tracking-[0.16em] text-white/40">{children}</div>
);

function Sparkline({ values, max }: { values: number[]; max: number }) {
  if (values.length < 2) return <div className="h-6" />;
  const w = 120, h = 32;
  const pts = values.map((v, i) => {
    const x = (i / (values.length - 1)) * w;
    const y = h - (v / max) * h;
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  });
  // No area fill: entropy sits near the top of its own range, so a filled region
  // reads as a solid block and hides the shape of the decline.
  return (
    <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" className="w-full h-6 overflow-visible">
      <line x1={0} y1={0} x2={w} y2={0} stroke="rgba(255,255,255,0.18)" strokeWidth={1} strokeDasharray="3 3" />
      <polyline points={pts.join(" ")} fill="none" stroke="var(--belief)" strokeWidth={2} vectorEffect="non-scaling-stroke" />
      <circle cx={w} cy={h - (values[values.length - 1] / max) * h} r={3} fill="var(--belief)" />
    </svg>
  );
}

export function Dashboard() {
  const [data, setData] = useState<Replay | null>(null);
  const [incidentIdx, setIncidentIdx] = useState(0);
  const [armKey, setArmKey] = useState("adaptive");
  const [step, setStep] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [hover, setHover] = useState<string | null>(null);
  // The map is evidence, not the answer. It can be put away, and the readouts take the
  // whole width when it is.
  const [showMap, setShowMap] = useState(true);
  // Draggable split, like a pair of editor panes. 70/30 by default: the map needs the
  // room, the readouts need to stay legible.
  const [splitPct, setSplitPct] = useState(70);
  const [dragging, setDragging] = useState(false);
  const splitRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!dragging) return;
    const move = (e: PointerEvent) => {
      const el = splitRef.current;
      if (!el) return;
      const r = el.getBoundingClientRect();
      setSplitPct(Math.min(82, Math.max(42, ((e.clientX - r.left) / r.width) * 100)));
    };
    const up = () => setDragging(false);
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", up);
    // Held on the body, because the pointer leaves the 14px handle almost immediately
    // and the cursor would otherwise flicker back mid-drag.
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
    return () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", up);
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
    };
  }, [dragging]);

  useEffect(() => {
    fetch("/replay.json").then((r) => r.json()).then(setData).catch(() => setData(null));
  }, []);

  const incident = data?.incidents[incidentIdx];
  const arm = incident?.arms[armKey];
  const steps = useMemo(() => arm?.steps ?? [], [arm]);
  const current = steps[Math.min(step, steps.length - 1)];
  const finished = step >= steps.length - 1;

  useEffect(() => setStep(0), [incidentIdx, armKey]);

  useEffect(() => {
    if (!playing || !steps.length) return;
    if (finished) return setPlaying(false);
    const t = setTimeout(() => setStep((s) => s + 1), 1500);
    return () => clearTimeout(t);
  }, [playing, step, finished, steps.length]);

  // EPANET coordinates are Y-up over arbitrary ranges, so normalise into the viewBox
  // and flip Y. Sources must be inside the bounds or the tank-connected pipes clip.
  const project = useMemo(() => {
    if (!data) return null;
    const all = [...data.network.junctions, ...data.network.sources];
    const xs = all.map((n) => n.x), ys = all.map((n) => n.y);
    const minX = Math.min(...xs), maxX = Math.max(...xs);
    const minY = Math.min(...ys), maxY = Math.max(...ys);
    // The viewBox takes the network's own aspect ratio. Forcing it into a square
    // left the plan floating in a field of dead space.
    const spanX = (maxX - minX) || 1;
    const spanY = (maxY - minY) || 1;
    const w = VIEW;
    const h = VIEW * (spanY / spanX);
    const scale = (w * (1 - 2 * PAD)) / spanX;
    const pos = new Map<string, { x: number; y: number }>();
    for (const n of all) {
      pos.set(n.id, {
        x: w * PAD + (n.x - minX) * scale,
        y: h * PAD + (maxY - n.y) * scale,
      });
    }
    // Nodes are already inset by PAD on every side, so the viewBox is exactly h.
    // Multiplying by (1 + 2*PAD) here added a second, empty 14% band.
    return { pos, w, h };
  }, [data]);

  const shell = (inner: React.ReactNode) => (
    <div className="h-svh overflow-hidden relative bg-[#00070F]">
      {/* Animated particle field in place of the template's static image. This is what
          the glass panels above refract. */}
      <ParticleBackground />
      <div className="absolute inset-0 bg-black/10 pointer-events-none" />
      <div className="relative z-10 h-svh p-3 md:p-4 flex flex-col gap-3">{inner}</div>
      <style jsx global>{`
        @keyframes flow { to { stroke-dashoffset: -16; } }
        @keyframes ripple {
          0% { opacity: 0.5; transform: scale(1); }
          100% { opacity: 0; transform: scale(2.8); }
        }
        @media (prefers-reduced-motion: reduce) {
          line, circle { animation: none !important; }
        }
        .rail::-webkit-scrollbar { width: 6px; }
        .rail::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.12); border-radius: 99px; }
      `}</style>
    </div>
  );

  if (!data || !project || !incident || !arm || !current) {
    return shell(
      <div className={`${PANEL} flex-1 grid place-items-center`}>
        <div className="font-mono text-sm text-white/50">Loading the network…</div>
      </div>
    );
  }

  const { junctions, sources, pipes, gauges } = data.network;
  const gaugeSet = new Set(gauges);
  const inSet = new Set(current.credibleSet);
  const { pos: nodePos, w: viewW, h: viewH } = project;
  const maxP = Math.max(...Object.values(current.posterior));

  // Heat is measured against chance on a fixed scale, never against the current
  // maximum. Dividing by the maximum renders a flat prior as total confidence,
  // because every junction ends up dividing by itself, and it makes an 8% leader
  // look identical to a 60% one.
  const chance = 1 / junctions.length;
  const heat = (p: number) => Math.max(0, Math.min(1, (p - chance) / (FULL_HEAT - chance)));
  const hasSignal = maxP > chance * 2;
  // Bars stay relative so the ranking is readable, and a chance tick is drawn into
  // each track so the absolute scale is never lost.
  const barScale = Math.max(maxP, chance * 4);
  const probesSoFar = steps.slice(0, step + 1).filter((s) => s.probeGauge).length;
  const priorEntropy = steps[0].entropyBits;
  const maxFlow = Math.max(...pipes.map((p) => Math.abs(p.flow)), 1);
  const gained = priorEntropy - current.entropyBits;
  const ranked = Object.entries(current.posterior).sort((a, b) => b[1] - a[1]);
  // Replayable = the arms this incident actually recorded. Measured = the arms carried
  // through the sweep. They are different sets and the UI should not pretend otherwise.
  // Deliberately NOT a hook: this sits below the component's early return, and a
  // conditionally-called useMemo changes hook order between renders.
  const ARM_LABEL: Record<string, string> = {
    randomControl: "random control", maxInfoGain: "max information gain",
    adaptive: "adaptive stopping", allGauges: "all gauges",
  };
  const replayableArms = Object.keys(incident?.arms ?? {}).map((k) => ({
    key: k,
    name: data.summary.arms.find((a) => a.key === k)?.name ?? ARM_LABEL[k] ?? k,
    measured: data.summary.arms.some((a) => a.key === k),
  }));
  const savedVsFixed = 3 - arm.probesUsed;

  const head = (
    <div className="flex items-baseline justify-between gap-3 shrink-0 mb-2">
      <h1 className="font-sentient text-xl md:text-2xl text-white leading-tight">
        What we know, and what we <i className="font-light">don&apos;t</i>
      </h1>
      {/* Lives on the panel it controls. In the command bar it pushed the transport
          controls onto a second row at 1440. */}
      <button
        onClick={() => setShowMap((v) => !v)}
        title={showMap ? "Put the map away and lead with the numbers" : "Show the network map"}
        style={{ transition: `all 200ms ${EASE}` }}
        className={`shrink-0 h-7 px-2 flex items-center gap-1.5 rounded-md border font-mono text-[9px] uppercase tracking-[0.14em] active:scale-[0.97] ${
          showMap
            ? "border-white/[0.15] text-white/50 hover:text-white hover:bg-white/[0.07]"
            : "border-[var(--belief)]/50 text-[var(--belief)] bg-[var(--belief)]/10"
        }`}
      >
        <MapIcon className="h-3 w-3" />
        {showMap ? "Map on" : "Map off"}
      </button>
    </div>
  );

  // The credible set is the actual output of this system, so it is named and enumerated,
  // never summarised. It becomes the headline when the map is put away.
  const credibleBlock = (big: boolean) => (
    <div className={`shrink-0 ${big ? "" : "mt-3 flex items-start gap-3"}`}>
      <div className={big ? "" : "shrink-0 pt-0.5"}>
        <Label>Credible set · 90%</Label>
        {big ? (
          <div className="font-mono text-white mt-1.5">
            <span className="text-5xl tabular-nums">{current.credibleSet.length}</span>
            <span className="text-sm text-white/45 ml-2.5">of {junctions.length} junctions still in play</span>
          </div>
        ) : (
          <div className="font-mono text-[10px] text-white/35 mt-0.5">
            {current.credibleSet.length} of {junctions.length} still in play
          </div>
        )}
      </div>
      <div className={`flex flex-wrap content-start ${big ? "gap-1.5 mt-4" : "gap-1"}`}>
        {current.credibleSet.map((id) => (
          <span
            key={id}
            onMouseEnter={() => setHover(id)}
            onMouseLeave={() => setHover(null)}
            className={`font-mono tabular-nums rounded border ${big ? "text-sm px-2.5 py-1" : "text-[11px] px-1.5 py-0.5"} ${
              hover === id
                ? "border-[var(--foam)]/70 text-[var(--foam)] bg-[var(--foam)]/10"
                : "border-[var(--cost)]/35 text-white/65"
            }`}
            style={{ transition: `all 160ms ${EASE}` }}
          >
            {id}
          </span>
        ))}
      </div>
      {big && (
        <p className="font-mono text-[11px] leading-relaxed text-white/40 mt-5 max-w-[540px]">
          These are the junctions the pressure evidence cannot separate. Picking one of them would
          be a guess, so the set is the answer we report. It is what {junctions.length} candidates
          narrowed to after {probesSoFar} {probesSoFar === 1 ? "reading" : "readings"}.
        </p>
      )}
    </div>
  );

  // The bottom band: what the network is, and what the four arms measured over 66
  // incidents. Reference data, so it sits out of the live panes and never scrolls.
  const bottomStrip = (
    <footer className={`${PANEL} shrink-0 h-[152px] px-5 py-4 flex items-start gap-6`}>
      <div className="shrink-0">
        <Label>Network</Label>
        <div className="font-mono text-[11px] text-white/65 mt-1 tabular-nums">
          {junctions.length} junctions · {pipes.length} pipes · {gauges.length} gauges
        </div>
        <div className="font-mono text-[10px] text-white/30 mt-0.5 tabular-nums">
          Leak {incident.leakGpm} gpm · gauge noise {data.summary.noisePsi} psi
        </div>
      </div>

      {data.fixture && (
        <span className="shrink-0 font-mono text-[9px] uppercase tracking-[0.16em] px-2 py-1 rounded border border-[var(--belief)]/35 text-[var(--belief)]/90">
          Fixture data
        </span>
      )}

      <div className="h-14 w-px bg-white/10 shrink-0 max-md:hidden" />

      <div className="flex-1 min-w-0">
        <div className="flex items-baseline justify-between gap-3 mb-1.5">
          <Label>Measured over {data.summary.nIncidents} incidents</Label>
          <span className="font-mono text-[10px] text-white/30">
            Top-5 accuracy · mean crew dispatches · chance {data.summary.chancePct}%
          </span>
        </div>
        <div className="grid grid-cols-5 gap-2">
          {[...data.summary.arms.map((a) => ({ ...a, isChance: false })),
            { key: "__chance", name: "chance", top5Pct: data.summary.chancePct, meanProbes: 0, isChance: true }].map((a) => {
            const on = armKey === a.key;
            return (
              <button
                key={a.key}
                onClick={() => !a.isChance && setArmKey(a.key)}
                disabled={a.isChance}
                style={{ transition: `all 180ms ${EASE}` }}
                className={`text-left rounded-lg px-3 py-2 border ${
                  a.isChance
                    ? "border-dashed border-white/10 cursor-default"
                    : on
                    ? "border-[var(--belief)]/45 bg-[var(--belief)]/[0.07] active:scale-[0.99]"
                    : "border-white/[0.07] hover:border-white/20 active:scale-[0.99]"
                }`}
              >
                <div className={`font-mono text-[10px] truncate ${a.isChance ? "text-white/30" : on ? "text-[var(--belief)]" : "text-white/50"}`}>
                  {sentenceCase(a.name)}
                </div>
                <div className="flex items-baseline gap-1.5 mt-0.5 font-mono tabular-nums">
                  <span className={`text-lg ${a.isChance ? "text-white/30" : on ? "text-[var(--belief)]" : "text-white/80"}`}>
                    {a.top5Pct}%
                  </span>
                  <span className={`text-[10px] ${a.isChance ? "text-white/25" : "text-[var(--cost)]"}`}>
                    {a.isChance ? "n/a" : `${a.meanProbes}p`}
                  </span>
                </div>
              </button>
            );
          })}
        </div>
        {/* Driven by the data, not hardcoded. The old copy asserted that no policy beat
            the control, which was true of the first fixture and is false of the measured
            run now feeding this page. */}
        <p className="font-mono text-[10px] text-white/30 mt-2.5 truncate">
          {data.summary.note ?? "Reported as measured, against a random control on every incident."}
        </p>
      </div>
    </footer>
  );

  const divider = (
    <div
      role="separator"
      aria-orientation="vertical"
      aria-valuenow={Math.round(splitPct)}
      tabIndex={0}
      onPointerDown={(e) => {
        e.preventDefault();
        setDragging(true);
      }}
      onDoubleClick={() => setSplitPct(70)}
      onKeyDown={(e) => {
        if (e.key === "ArrowLeft") setSplitPct((v) => Math.max(42, v - 2));
        if (e.key === "ArrowRight") setSplitPct((v) => Math.min(82, v + 2));
      }}
      title="Drag to resize, double-click to reset"
      className="group relative cursor-col-resize touch-none outline-none max-lg:hidden"
    >
      <div
        className={`absolute inset-y-0 left-1/2 -translate-x-1/2 w-px ${
          dragging ? "bg-[var(--belief)]/70" : "bg-white/15 group-hover:bg-white/40 group-focus:bg-white/40"
        }`}
        style={{ transition: `background 150ms ${EASE}` }}
      />
      <div
        className={`absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 h-12 w-[3px] rounded-full ${
          dragging ? "bg-[var(--belief)]" : "bg-white/25 group-hover:bg-white/55 group-focus:bg-white/55"
        }`}
        style={{ transition: `background 150ms ${EASE}` }}
      />
    </div>
  );

  return shell(
    <>
      {/* Command bar */}
      <header className={`${PANEL} px-3.5 py-2.5 flex items-center gap-3 shrink-0`}>
        <Link href="/" className="shrink-0">
          <Logo className="w-[112px]" />
        </Link>

        <div className="h-6 w-px bg-white/10 max-md:hidden" />

        <div className="flex items-center gap-2">
          <select
            className="bg-white/[0.06] border border-white/[0.13] rounded-lg pl-2.5 pr-7 h-8 font-mono text-xs text-white outline-none focus:border-[var(--belief)] appearance-none bg-no-repeat"
            style={{
              backgroundImage:
                "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='10' height='10' viewBox='0 0 10 10'><path d='M1 3l4 4 4-4' stroke='rgba(255,255,255,0.5)' stroke-width='1.4' fill='none'/></svg>\")",
              backgroundPosition: "right 8px center",
            }}
            value={incidentIdx}
            onChange={(e) => setIncidentIdx(+e.target.value)}
          >
            {data.incidents.map((inc, i) => (
              <option key={inc.id} value={i} className="bg-[#00121A]">
                {inc.id} · {inc.leakGpm} gpm
              </option>
            ))}
          </select>
        </div>

        <div className="flex items-center gap-1.5 flex-wrap">
          {replayableArms.map((a) => (
            <button
              key={a.key}
              onClick={() => setArmKey(a.key)}
              style={{ transition: `all 200ms ${EASE}` }}
              className={`font-mono text-[11px] px-2.5 h-8 rounded-lg border active:scale-[0.97] ${
                armKey === a.key
                  ? "border-[var(--belief)]/50 text-[var(--belief)] bg-[var(--belief)]/10"
                  : "border-white/10 text-white/50 hover:text-white hover:bg-white/[0.06]"
              }`}
            >
              {sentenceCase(a.name)}
              {!a.measured && <span className="ml-1.5 text-white/25">· replay only</span>}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-2.5 ml-auto">
          {/* The marketing header is hidden on this route, so the rest of the site has
              to stay reachable from here or the demo is a dead end for a judge. */}
          <nav className="flex items-center gap-3 mr-1 max-xl:hidden">
            {[
              { label: "Method", href: "/method" },
              { label: "Results", href: "/results" },
              { label: "Limits", href: "/limits" },
            ].map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="font-mono text-[10px] uppercase tracking-[0.12em] text-white/35 hover:text-white"
                style={{ transition: `color 150ms ${EASE}` }}
              >
                {item.label}
              </Link>
            ))}
          </nav>

          {/* Fixed-width track: the all-gauges arm has nine steps and fixed-width pips
              wrapped the command bar onto a second row. */}
          <div className="flex gap-1 mr-1 w-[132px] shrink-0">
            {steps.map((_, i) => (
              <div
                key={i}
                className="h-1.5 flex-1 rounded-full"
                style={{
                  background: i <= step ? "var(--belief)" : "rgba(255,255,255,0.13)",
                  transition: `background 200ms ${EASE}`,
                }}
              />
            ))}
          </div>
          <button
            onClick={() => (finished ? (setStep(0), setPlaying(true)) : setPlaying((p) => !p))}
            style={{ transition: `all 200ms ${EASE}` }}
            className="flex items-center gap-2 font-mono text-xs px-3.5 h-9 rounded-lg border border-[var(--belief)]/50 text-[var(--belief)] bg-[var(--belief)]/10 hover:bg-[var(--belief)]/20 active:scale-[0.97]"
          >
            {playing ? <Pause className="h-3.5 w-3.5" /> : finished ? <RotateCcw className="h-3.5 w-3.5" /> : <Play className="h-3.5 w-3.5" />}
            {playing ? "Pause" : finished ? "Replay" : "Play"}
          </button>
          <button
            onClick={() => setStep((s) => Math.min(s + 1, steps.length - 1))}
            style={{ transition: `all 200ms ${EASE}` }}
            className="h-9 w-9 grid place-items-center rounded-lg border border-white/[0.13] text-white/60 hover:text-white hover:bg-white/[0.06] active:scale-[0.97]"
          >
            <SkipForward className="h-3.5 w-3.5" />
          </button>
        </div>
      </header>

      <div
        ref={splitRef}
        className="min-h-0 grid max-lg:!grid-cols-1 max-lg:gap-3 max-lg:overflow-y-auto"
        style={{
          gridTemplateColumns: `${splitPct}% 14px minmax(0, 1fr)`,
          // Capped rather than flex-1: the panes were taller than their content needed
          // and it pushed the specs band onto the bottom edge.
          height: "min(560px, calc(100svh - 266px))",
        }}
      >
        {showMap ? (
        <section className={`${PANEL} p-4 flex flex-col min-h-0 min-w-0`}>
          {head}

          <div className={`flex-1 min-h-0 ${WELL}`}>
            <svg viewBox={`0 0 ${viewW} ${viewH}`} preserveAspectRatio="xMidYMid meet" className="w-full h-full block">
              <defs>
                <radialGradient id="peak">
                  <stop offset="0%" stopColor="var(--belief)" stopOpacity="0.35" />
                  <stop offset="100%" stopColor="var(--belief)" stopOpacity="0" />
                </radialGradient>
              </defs>

              {/* Only glow once a leader has actually pulled clear of chance. At the
                  prior this would otherwise spotlight an arbitrary tie-break winner. */}
              {hasSignal && (() => {
                const p = nodePos.get(ranked[0][0]);
                return p ? (
                  <circle cx={p.x} cy={p.y} r={110} fill="url(#peak)" opacity={heat(maxP)} style={{ transition: `all 300ms ${EASE}` }} />
                ) : null;
              })()}

              {/* Static mains under the flow dashes, as one path so the pipe count in
                  the DOM stays honest. Without it the network reads as dotted, not piped. */}
              <path
                d={pipes
                  .map((p) => {
                    const a = nodePos.get(p.from)!, b = nodePos.get(p.to)!;
                    return `M${a.x.toFixed(1)} ${a.y.toFixed(1)}L${b.x.toFixed(1)} ${b.y.toFixed(1)}`;
                  })
                  .join("")}
                stroke="#25505F"
                strokeWidth={2}
                fill="none"
              />

              {pipes.map((p) => {
                const a = nodePos.get(p.from)!, b = nodePos.get(p.to)!;
                const dur = 6 - (Math.abs(p.flow) / maxFlow) * 5.2;
                return (
                  <line
                    key={p.id}
                    x1={a.x} y1={a.y} x2={b.x} y2={b.y}
                    stroke="#3D7C94" strokeWidth={2} strokeDasharray="6 10"
                    style={{ animation: `flow ${dur.toFixed(2)}s linear infinite` }}
                  />
                );
              })}

              {sources.map((s) => {
                const p = nodePos.get(s.id)!;
                return (
                  <g key={s.id}>
                    <rect x={p.x - 6} y={p.y - 6} width={12} height={12} fill="none" stroke="#8FA6B4" strokeWidth={1.5} />
                    <text x={p.x + 11} y={p.y + 4} fill="#8FA6B4" fontSize={13} fontFamily="monospace">{s.id}</text>
                  </g>
                );
              })}

              {junctions.map((j) => {
                const p = nodePos.get(j.id)!;
                const prob = current.posterior[j.id] ?? 0;
                const t = heat(prob);
                const r = 5 + t * 9;
                // Floor is a legible slate, not the background: a junction at chance is
                // still a junction, and 22 of them have to read as a network.
                const fill = `rgb(${Math.round(74 - t * 29)}, ${Math.round(114 + t * 98)}, ${Math.round(134 + t * 57)})`;
                const isHover = hover === j.id;
                return (
                  <g key={j.id} onMouseEnter={() => setHover(j.id)} onMouseLeave={() => setHover(null)} style={{ cursor: "pointer" }}>
                    {t > 0.15 && (
                      <circle
                        cx={p.x} cy={p.y} r={r} fill="none" stroke="var(--belief)" strokeWidth={1.5} opacity={0}
                        style={{ animation: `ripple 2.4s ${EASE} infinite`, animationDelay: `${(+j.id % 7) * 0.3}s` }}
                      />
                    )}
                    {gaugeSet.has(j.id) && (
                      <circle cx={p.x} cy={p.y} r={r + 5} fill="none" stroke="var(--belief)" strokeWidth={1} opacity={0.45} />
                    )}
                    {inSet.has(j.id) && (
                      <circle cx={p.x} cy={p.y} r={r + 2.5} fill="none" stroke="var(--foam)" strokeWidth={1} strokeDasharray="3 3" opacity={0.7} />
                    )}
                    <circle cx={p.x} cy={p.y} r={r} fill={fill} style={{ transition: `all 220ms ${EASE}` }} />
                    {current.probeGauge === j.id && (
                      <circle cx={p.x} cy={p.y} r={r + 10} fill="none" stroke="var(--cost)" strokeWidth={2} />
                    )}
                    {/* Invisible larger hit area so hover is usable at these radii */}
                    <circle cx={p.x} cy={p.y} r={18} fill="transparent" />
                    {isHover && (
                      <g pointerEvents="none">
                        <rect x={p.x + 14} y={p.y - 30} width={116} height={38} rx={6} fill="#00121A" stroke="rgba(255,255,255,0.2)" />
                        <text x={p.x + 22} y={p.y - 15} fill="white" fontSize={13} fontFamily="monospace">Junction {j.id}</text>
                        <text x={p.x + 22} y={p.y + 1} fill="var(--belief)" fontSize={13} fontFamily="monospace">
                          {(prob * 100).toFixed(1)}% belief
                        </text>
                      </g>
                    )}
                  </g>
                );
              })}

              {finished && (() => {
                const p = nodePos.get(incident.trueLeakJunction)!;
                return (
                  <g pointerEvents="none">
                    <rect x={p.x - 11} y={p.y - 11} width={22} height={22} fill="none" stroke="#63798C" strokeWidth={1.5} />
                    <text x={p.x + 16} y={p.y - 12} fill="#63798C" fontSize={12} fontFamily="monospace">Ground truth (evaluation only)</text>
                  </g>
                );
              })()}
            </svg>
          </div>

          {credibleBlock(false)}

          {/* Legend */}
          <div className="shrink-0 flex flex-wrap items-center gap-x-5 gap-y-1.5 mt-2.5 font-mono text-[10px] text-white/45">
            <span className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-full bg-[var(--belief)]" /> Belief mass</span>
            <span className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-full border border-[var(--belief)]/60" /> Gauge</span>
            <span className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-full border border-dashed border-[var(--foam)]/70" /> In credible set</span>
            <span className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-full border-2 border-[var(--cost)]" /> Probed now</span>
            <span className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 border border-[#8FA6B4]" /> Source</span>
          </div>

        </section>
        ) : (
        <section className={`${PANEL} p-5 flex flex-col min-h-0 min-w-0`}>
          {head}
          <div className="flex-1 min-h-0 flex flex-col justify-center py-2">{credibleBlock(true)}</div>
        </section>
        )}

        {divider}

        {/* Right rail */}
        <aside className="min-h-0 min-w-0 flex flex-col gap-3">
          <div className="grid grid-cols-2 gap-3">
            <div className={`${PANEL} p-3.5`}>
              <Label>Uncertainty</Label>
              <div className="font-mono text-2xl mt-0.5 tabular-nums text-white">
                {current.entropyBits.toFixed(2)}
                <span className="text-xs text-white/40 ml-1.5">bits</span>
              </div>
              <Sparkline values={steps.slice(0, step + 1).map((s) => s.entropyBits)} max={priorEntropy} />
              <div className="font-mono text-[10px] text-white/40">
                −{gained.toFixed(2)} from {priorEntropy.toFixed(2)}
              </div>
            </div>

            <div className={`${PANEL} p-3.5`}>
              <Label>Dispatches</Label>
              <div className="font-mono text-2xl mt-0.5 tabular-nums text-[var(--cost)]">
                {probesSoFar}
                <span className="text-xs text-white/40 ml-1.5">of {arm.probesUsed}</span>
              </div>
              <div className="mt-1.5 h-6 flex items-end gap-1">
                {Array.from({ length: Math.max(arm.probesUsed, 3) }).map((_, i) => (
                  <div
                    key={i}
                    className="flex-1 rounded-sm"
                    style={{
                      height: i < arm.probesUsed ? "100%" : "34%",
                      background: i < probesSoFar ? "var(--cost)" : "rgba(255,255,255,0.10)",
                      transition: `background 220ms ${EASE}`,
                    }}
                  />
                ))}
              </div>
              <div className="font-mono text-[10px] text-white/40 mt-1">
                {savedVsFixed > 0 ? `${savedVsFixed} fewer than the fixed arms` : "Crews sent to a street"}
              </div>
            </div>
          </div>

          <div className={`${PANEL} p-3.5`}>
            <div className="mb-2.5"><Label>Leading candidates</Label></div>
            <div className="space-y-1">
              {ranked.slice(0, 6).map(([id, p]) => (
                <div
                  key={id}
                  onMouseEnter={() => setHover(id)}
                  onMouseLeave={() => setHover(null)}
                  className={`flex items-center gap-2.5 rounded-lg px-2 py-0.5 ${hover === id ? "bg-white/[0.07]" : ""}`}
                  style={{ transition: `background 160ms ${EASE}` }}
                >
                  <span className="font-mono text-[11px] text-white/55 w-6 tabular-nums">{id}</span>
                  <div className="relative flex-1 h-1.5 rounded-full bg-white/[0.08] overflow-hidden">
                    {/* scaleX rather than width: these redraw on every probe step, and
                        animating width forces layout on each frame. */}
                    <div
                      className="h-full w-full rounded-full origin-left"
                      style={{
                        transform: `scaleX(${p / barScale})`,
                        background: "linear-gradient(90deg, var(--belief-deep), var(--belief))",
                        transition: `transform 260ms ${EASE}`,
                      }}
                    />
                    <div
                      className="absolute inset-y-0 w-px bg-white/35"
                      style={{ left: `${(chance / barScale) * 100}%`, transition: `left 260ms ${EASE}` }}
                    />
                  </div>
                  <span className="font-mono text-[11px] text-white/70 tabular-nums w-11 text-right">
                    {(p * 100).toFixed(1)}%
                  </span>
                  {inSet.has(id) && <span className="h-1.5 w-1.5 rounded-full bg-[var(--foam)]" title="In the credible set" />}
                </div>
              ))}
            </div>
            <div className="font-mono text-[10px] text-white/40 mt-2.5 pt-2.5 border-t border-white/[0.08]">
              Top-1 is not a call we make.
            </div>
          </div>

          <div className={`${PANEL} p-3.5 flex-1 min-h-0 flex flex-col`}>
            <div className="mb-2.5"><Label>Probe log</Label></div>
            <div className="rail space-y-1 flex-1 min-h-0 overflow-y-auto">
              {steps.slice(0, step + 1).map((s, i) => {
                const prev = i > 0 ? steps[i - 1].entropyBits : null;
                const drop = prev !== null ? prev - s.entropyBits : 0;
                return (
                  <div key={i} className="flex items-center gap-2 font-mono text-[11px] tabular-nums">
                    <span className="text-white/30 w-4">{i}</span>
                    <span className={s.probeGauge ? "text-white/75" : "text-white/40"}>
                      {s.probeGauge ? `Gauge ${s.probeGauge}` : "Prior"}
                    </span>
                    <span className="text-white/45">{s.readingPsi !== null ? `${s.readingPsi.toFixed(1)} psi` : "n/a"}</span>
                    <span className="ml-auto text-[var(--belief)]">
                      {i === 0 ? `${s.entropyBits.toFixed(2)}b` : `−${drop.toFixed(2)}b`}
                    </span>
                  </div>
                );
              })}
            </div>
            <div className="mt-2.5 pt-2.5 border-t border-white/[0.08] shrink-0">
              <Label>Last probe</Label>
              <div className="grid grid-cols-3 gap-2 mt-1.5 font-mono tabular-nums">
                <div>
                  <div className="text-sm text-white/85">{current.probeGauge ? `Gauge ${current.probeGauge}` : "n/a"}</div>
                  <div className="text-[10px] text-white/35">Read</div>
                </div>
                <div>
                  <div className="text-sm text-white/85">
                    {current.readingPsi !== null ? current.readingPsi.toFixed(2) : "n/a"}
                  </div>
                  <div className="text-[10px] text-white/35">psi</div>
                </div>
                <div>
                  <div className="text-sm text-[var(--belief)]">
                    {current.eigBits !== null ? current.eigBits.toFixed(3) : "n/a"}
                  </div>
                  <div className="text-[10px] text-white/35">Bits expected</div>
                </div>
              </div>
              <div className="font-mono text-[10px] text-white/30 mt-2">
                Gauge noise {data.summary.noisePsi} psi
              </div>
            </div>
          </div>

        </aside>
      </div>

      {bottomStrip}
    </>
  );
}
