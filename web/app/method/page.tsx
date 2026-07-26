"use client";

import { Callout, DocPage, Expr, Note, Readout } from "@/components/doc-page";
import { Leva } from "leva";

export default function MethodPage() {
  return (
    <>
      <DocPage
        sheet="Sheet 01 / Method"
        title={
          <>
            How Rivus
            <br />
            <i className="font-light">narrows</i> a leak
          </>
        }
        lede="A hydraulic forward model, a likelihood that admits its own error, and a probe policy that stops once the next crew is no longer worth sending."
        meta={["Anytown multipointcurves", "22 junctions", "8 gauges", "leak 400 gpm"]}
      >
        <Note mark="43" markUnit="pipes solved" heading="The forward model">
          <p>
            EPANET solves pressures at every junction for a candidate leak. The network is Anytown_multipointcurves, a
            published benchmark bundled with wntr. Of the 33 bundled networks only 8 produce physically valid
            hydraulics, and plain Anytown.inp diverges to 1e25.
          </p>
          <p>
            Leaks enter as added demand in GPM, not as emitters. Emitter leaks saturate: 0.5 and 30.0 produced identical
            30 psi drops and drove junctions negative. Added demand stays linear and controllable.
          </p>
        </Note>

        <Note mark="1.34" markUnit="psi combined σ" heading="Why gauge noise alone is not the likelihood">
          <p>
            The obvious likelihood compares predicted against observed pressure using the 0.35 psi sensor noise. Applied
            to perturbed data it reported entropy 0.000 while being wrong 95% of the time.
          </p>
          <Callout tone="warn">
            Certainty and error at once is the worst available failure for a product whose whole claim is that it
            reports what it cannot know.
          </Callout>
          <p>Sensor error and forward-model error add in quadrature, so the likelihood widens to admit how wrong the simulator is:</p>
          <Expr>σ = √(0.35² + model_σ²) &nbsp;·&nbsp; model_σ = 1.30 from measured divergence</Expr>
          <p>
            Sigma moves calibration, not ranking. Swept from 0.01 to 5.0, exact holds at 4.5% and top-5 at 30.3% while
            mean entropy travels 0.0 to 4.342 bits. Honest uncertainty costs nothing, so there is no accuracy argument
            for staying overconfident.
          </p>
        </Note>

        <Note mark="0.226" markUnit="max bits per gauge" heading="Choosing the next gauge">
          <p>
            Each candidate probe is scored by the bits the posterior is expected to lose once that gauge is read.
            Information gain only survives an honest sigma:
          </p>
          <Readout
            head={["model σ", "EIG range across 8 gauges"]}
            rows={[
              ["0.5", "0.006 – 0.627 bits"],
              ["1.3", "0.000 – 0.226 bits"],
              ["2.5", "0.000 – 0.040 bits"],
            ]}
            mark={1}
            caption="At σ 2.5 no gauge carries information and max-infogain collapses into random. Sigma comes from measured divergence, never chosen defensively."
          />
        </Note>

        <Note mark="2" markUnit="probes at θ 0.50" heading="Knowing when to stop">
          <p>
            Every probe is a crew dispatched to a street, so the policy halts once the next probe buys fewer than θ bits,
            or the budget runs out. Replaying a decaying information sequence:
          </p>
          <Readout
            head={["threshold θ", "probes", "bits gained"]}
            rows={[
              ["0.50", "2", "1.81"],
              ["0.15", "3", "1.99"],
              ["0.05", "3", "1.99"],
              ["0.00", "5", "2.04"],
              ["fixed-3 arm", "3", "1.99"],
            ]}
            mark={0}
            caption="At θ 0.50 the policy keeps 91% of the information for two thirds of the probes."
          />
          <p>
            This arm will not beat fixed-3 on accuracy and is not meant to. Its win is equal accuracy at lower cost,
            which is why probes spent is a first-class column everywhere in this product rather than a footnote.
          </p>
        </Note>

        <Note mark="0.35" markUnit="psi noise floor" heading="Proving it is not circular">
          <p>
            If diagnosis merely inverts the simulator that produced the evidence, the result means nothing. The defence
            is that staging perturbs demands and roughness before observations are drawn, and that defence is only real
            if perturbed and nominal baselines diverge by more than the noise floor.
          </p>
          <p>
            So the gate measures per-gauge divergence between the two models and requires the median to clear 0.35 psi.
            It runs across the same seeds the evaluation uses and gates on the worst seed, not the mean, because a check
            that cannot fail is not a check.
          </p>
        </Note>
      </DocPage>
      <Leva hidden />
    </>
  );
}
