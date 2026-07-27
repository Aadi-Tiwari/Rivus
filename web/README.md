# Rivus, web

Demo frontend for Rivus, Bayesian leak localisation over water distribution networks.

## Run

```bash
pnpm install
cd .. && jac run jac/export_web.jac && cd web   # regenerates public/replay.json
pnpm dev
```

## How it works

The page is a **pure replay player**. There is no backend and no live call into the
Jac evaluation. Everything on screen is read from `public/replay.json`, so the demo
is deterministic on stage and can be built on any machine.

`jac/export_web.jac` runs the Jac engine over the real EPANET network and emits that
file, so the posteriors are measured rather than synthetic. The page shows a
`FIXTURE DATA` badge whenever the root `fixture` flag is true, which is how a
placeholder run announces itself. The measured export sets it false and the badge
disappears with no code change.

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
