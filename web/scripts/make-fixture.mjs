// Builds public/replay.json from the real EPANET network file.
//
// The posteriors here are SYNTHETIC. They exist so the replay player can be built
// and demoed before the Jac evaluation has been run. Real output replaces this file
// with no code change, and the "fixture": true flag drives the on-screen badge.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const INP = join(here, "..", "..", "temp.inp");
const OUT = join(here, "..", "public", "replay.json");

const EXPECT = { junctions: 22, sources: 3, pipes: 43 };
const GAUGE_STRIDE = 3; // every third junction carries a pressure gauge
const NOISE_PSI = 0.35;

function sections(text) {
  const out = {};
  let current = null;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith(";")) continue;
    const header = line.match(/^\[([A-Z]+)\]$/);
    if (header) {
      current = header[1];
      out[current] = [];
      continue;
    }
    if (current) out[current].push(line.split(/\s+/).filter(Boolean));
  }
  return out;
}

// Deterministic PRNG so the fixture is byte-identical between runs and the demo
// never shifts under you between rehearsal and stage.
function mulberry32(seed) {
  return function () {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const S = sections(readFileSync(INP, "utf8"));

const junctionIds = S.JUNCTIONS.map((r) => r[0]);
const sourceKind = new Map();
for (const r of S.RESERVOIRS ?? []) sourceKind.set(r[0], "reservoir");
for (const r of S.TANKS ?? []) sourceKind.set(r[0], "tank");

const coords = new Map();
for (const [id, x, y] of S.COORDINATES) coords.set(id, { x: +x, y: +y });

const junctions = junctionIds.map((id) => ({ id, ...coords.get(id) }));
const sources = [...sourceKind].map(([id, kind]) => ({ id, ...coords.get(id), kind }));

// Pipe endpoints reference tanks and the reservoir as well as junctions, so the
// coordinate lookup must span every node type or those pipes silently vanish.
const pipes = S.PIPES.map((r) => ({
  id: r[0],
  from: r[1],
  to: r[2],
  // No hydraulic solve here; diameter over length is a stand-in for relative flow
  // purely so the flow animation has something to vary on.
  flow: Math.round((+r[4] * +r[4] * 1000) / +r[3]),
}));

for (const p of pipes) {
  if (!coords.has(p.from) || !coords.has(p.to)) {
    throw new Error(`pipe ${p.id} references unknown node ${p.from} or ${p.to}`);
  }
}

if (junctions.length !== EXPECT.junctions || sources.length !== EXPECT.sources || pipes.length !== EXPECT.pipes) {
  throw new Error(
    `parse mismatch: got ${junctions.length} junctions, ${sources.length} sources, ` +
      `${pipes.length} pipes; expected ${EXPECT.junctions}/${EXPECT.sources}/${EXPECT.pipes}`
  );
}

const gauges = junctionIds.filter((_, i) => i % GAUGE_STRIDE === 0);

// Hop distance over the pipe graph, used to make the synthetic posterior fall off
// from the true leak in a way that respects real network topology.
const adj = new Map(junctionIds.map((id) => [id, []]));
for (const p of pipes) {
  if (adj.has(p.from) && adj.has(p.to)) {
    adj.get(p.from).push(p.to);
    adj.get(p.to).push(p.from);
  }
}
function hops(from) {
  const dist = new Map([[from, 0]]);
  const queue = [from];
  while (queue.length) {
    const n = queue.shift();
    for (const m of adj.get(n) ?? []) {
      if (!dist.has(m)) {
        dist.set(m, dist.get(n) + 1);
        queue.push(m);
      }
    }
  }
  return dist;
}

const entropy = (post) =>
  Object.values(post).reduce((h, p) => (p > 0 ? h - p * Math.log2(p) : h), 0);

function normalize(weights) {
  const total = Object.values(weights).reduce((a, b) => a + b, 0);
  const out = {};
  for (const k of Object.keys(weights)) out[k] = weights[k] / total;
  return out;
}

// The posterior peaks on a decoy one or two hops from the true leak, never on the
// leak itself. That is what the measured evaluation actually looks like: the true
// junction usually sits inside the credible set while top-1 is near chance. A
// fixture centred on the truth would show ~100% exact and contradict the findings.
function decoyFor(trueLeak, rand) {
  const d = hops(trueLeak);
  const near = junctionIds.filter((id) => {
    const h = d.get(id);
    return h === 1 || h === 2;
  });
  return near.length ? near[Math.floor(rand() * near.length)] : trueLeak;
}

// sharpness 0 = uniform prior, rising values concentrate mass around the centre.
function posteriorAt(centre, sharpness, rand) {
  const d = hops(centre);
  const w = {};
  for (const id of junctionIds) {
    const h = d.get(id) ?? 6;
    w[id] = Math.exp(-sharpness * h) * (0.72 + rand() * 0.56);
  }
  return normalize(w);
}

function credibleSet(post, mass = 0.9) {
  const ranked = Object.entries(post).sort((a, b) => b[1] - a[1]);
  const out = [];
  let acc = 0;
  for (const [id, p] of ranked) {
    out.push(id);
    acc += p;
    if (acc >= mass) break;
  }
  return out;
}

// Deliberately modest: the measured evaluation puts these arms at or near the
// 1/22 chance rate, so the fixture must not imply the system pinpoints the pipe.
const ARMS = {
  // Tuned so the 90% credible set actually covers the truth about 90% of the time.
  // Sharper looks better on stage but under-covers, which is the confident-and-wrong
  // failure mode the findings call out as the worst outcome for this product.
  adaptive: { probes: 1, sharp: [0.0, 1.30] },
  maxInfoGain: { probes: 3, sharp: [0.0, 0.62, 1.00, 1.36] },
  randomControl: { probes: 3, sharp: [0.0, 0.34, 0.70, 1.08] },
  allGauges: { probes: gauges.length, sharp: [0.0, 0.40, 0.64, 0.84, 1.00, 1.14, 1.24, 1.32, 1.38] },
};

const rand = mulberry32(20260726);
const incidents = [];

for (let i = 0; i < 8; i++) {
  const trueLeakJunction = junctionIds[Math.floor(rand() * junctionIds.length)];
  const arms = {};

  for (const [name, cfg] of Object.entries(ARMS)) {
    const centre = decoyFor(trueLeakJunction, rand);
    const steps = [];
    for (let s = 0; s <= cfg.probes; s++) {
      const post = posteriorAt(centre, cfg.sharp[s] ?? cfg.sharp.at(-1), rand);
      const set = credibleSet(post);
      steps.push({
        probeGauge: s === 0 ? null : gauges[(i + s) % gauges.length],
        readingPsi: s === 0 ? null : +(38 + rand() * 14).toFixed(2),
        eigBits: s === 0 ? null : +(1.3 * Math.pow(0.42, s - 1) + rand() * 0.05).toFixed(3),
        posterior: Object.fromEntries(Object.entries(post).map(([k, v]) => [k, +v.toFixed(5)])),
        entropyBits: +entropy(post).toFixed(3),
        credibleSet: set,
      });
    }
    const last = steps.at(-1);
    const ranked = Object.entries(last.posterior).sort((a, b) => b[1] - a[1]);
    arms[name] = {
      steps,
      probesUsed: cfg.probes,
      exactHit: ranked[0][0] === trueLeakJunction,
      top5Hit: ranked.slice(0, 5).some(([id]) => id === trueLeakJunction),
    };
  }

  incidents.push({ id: `INC-${String(i + 1).padStart(3, "0")}`, trueLeakJunction, leakGpm: 400, arms });
}

// These four rows are the MEASURED numbers from FINDINGS-PERSON-B.md, not synthetic.
const replay = {
  fixture: true,
  network: { junctions, sources, pipes, gauges },
  incidents,
  summary: {
    nIncidents: 66,
    chancePct: +(100 / junctions.length).toFixed(1),
    noisePsi: NOISE_PSI,
    arms: [
      { name: "random control", key: "randomControl", exactPct: 7.6, top5Pct: 31.8, meanHops: 2.09, meanProbes: 3.0 },
      { name: "max information gain", key: "maxInfoGain", exactPct: 4.5, top5Pct: 27.3, meanHops: 2.18, meanProbes: 3.0 },
      { name: "adaptive stopping", key: "adaptive", exactPct: 4.5, top5Pct: 22.7, meanHops: 2.18, meanProbes: 1.0 },
      { name: "all 8 gauges", key: "allGauges", exactPct: 4.5, top5Pct: 30.3, meanHops: 2.18, meanProbes: 8.0 },
    ],
  },
};

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(replay));

// Sanity-check the fixture against the findings: top-1 must stay near chance while
// the credible set usually contains the truth. If exact ever climbs high, the
// fixture is lying about what the system can do.
const flat = incidents.flatMap((inc) => Object.values(inc.arms));
const exact = flat.filter((a) => a.exactHit).length;
const top5 = flat.filter((a) => a.top5Hit).length;
const contains = incidents.flatMap((inc) =>
  Object.values(inc.arms).map((a) => a.steps.at(-1).credibleSet.includes(inc.trueLeakJunction))
).filter(Boolean).length;
const finalEnt = flat.map((a) => a.steps.at(-1).entropyBits);
const setSizes = flat.map((a) => a.steps.at(-1).credibleSet.length);
const mean = (xs) => xs.reduce((a, b) => a + b, 0) / xs.length;

console.log(
  `wrote ${OUT}\n` +
    `  ${junctions.length} junctions, ${sources.length} sources, ${pipes.length} pipes, ${gauges.length} gauges\n` +
    `  ${incidents.length} incidents x ${Object.keys(ARMS).length} arms = ${flat.length} runs\n` +
    `  prior entropy ${entropy(Object.fromEntries(junctionIds.map((id) => [id, 1 / junctionIds.length]))).toFixed(3)} bits\n` +
    `  final entropy  mean ${mean(finalEnt).toFixed(2)} bits\n` +
    `  credible set   mean ${mean(setSizes).toFixed(1)} of ${junctions.length}, contains truth ${((100 * contains) / flat.length).toFixed(0)}%\n` +
    `  exact ${((100 * exact) / flat.length).toFixed(1)}%  top5 ${((100 * top5) / flat.length).toFixed(1)}%  (chance ${(100 / junctions.length).toFixed(1)}%)`
);
