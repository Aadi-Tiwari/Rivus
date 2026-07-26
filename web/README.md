# Rivus, web

Demo frontend for Rivus, Bayesian leak localisation over water distribution networks.

## Run

```bash
pnpm install
node scripts/make-fixture.mjs   # regenerates public/replay.json from ../temp.inp
pnpm dev
```

## How it works

The page is a **pure replay player**. There is no backend and no live call into the
Jac evaluation. Everything on screen is read from `public/replay.json`, so the demo
is deterministic on stage and can be built on any machine.

`scripts/make-fixture.mjs` parses the real EPANET network at `../temp.inp` and emits
that file. It asserts 22 junctions, 3 sources and 43 pipes, and fails loudly if the
parse drifts. The posteriors it generates are **synthetic**, which is why the page
shows a `FIXTURE DATA` badge, driven by the `fixture: true` flag at the root of the
JSON. Replacing the file with real evaluation output requires no code change and
removes the badge.

## What this UI deliberately does not claim

Measured accuracy for exact-junction identification sits at or near the 1/22 chance
rate. So the UI never asserts a specific leaking pipe. It shows a credible set, the
entropy still remaining in bits, and the number of crew dispatches spent. The
defensible result is equal accuracy at one third of the truck rolls, and that is the
claim the page makes.

The fixture is tuned so the 90% credible set actually contains the truth about 90% of
the time. Sharper posteriors look better on stage but under-cover, which is the
confident-and-wrong failure mode that matters most here.

Ground truth is revealed only after playback completes, labelled evaluation-only.
