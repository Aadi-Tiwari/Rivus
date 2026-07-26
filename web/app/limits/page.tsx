"use client";

import { Callout, DocPage, Note } from "@/components/doc-page";
import { Leva } from "leva";

export default function LimitsPage() {
  return (
    <>
      <DocPage
        sheet="Sheet 03 / Limits"
        title={
          <>
            What Rivus
            <br />
            <i className="font-light">cannot</i> tell you
          </>
        }
        lede="The failure modes are known and written down. If a claim is not on the results sheet, we are not making it."
        meta={["one network", "arbitrary gauge set", "synthetic demo data"]}
      >
        <Note mark="1 / 22" markUnit="exact-junction rate" heading="It does not find the pipe">
          <Callout tone="warn">
            Rivus does not identify the leaking pipe. Exact-junction accuracy sits at chance in the regime that passes
            the non-circularity gate, and any interface implying otherwise would contradict our own measurements.
          </Callout>
          <p>
            What it does produce is a calibrated set and a cost. Those are the two things the interface is allowed to
            put on screen.
          </p>
        </Note>

        <Note mark="8 ≈ 3" markUnit="gauges vs random" heading="The forward model is probably misspecified">
          <p>
            Reading all eight gauges performs no better than reading three chosen at random. That is the signature of a
            misspecified forward model rather than a weak probe policy: more information is not helping, so the map from
            leak to pressure is not close enough to reality for the extra readings to carry signal.
          </p>
          <p>
            Until that resolves, no policy should be expected to separate from the control on accuracy, and the
            roughness-CV question has to be settled first.
          </p>
        </Note>

        <Note mark="n/3" markUnit="every third junction" heading="Gauge placement is arbitrary">
          <p>
            The gauge set is every third junction. That is not optimised and not drawn from any real deployment. Real
            placement would move every number reported here, so nothing on these sheets should be read as guidance on
            how many gauges a network needs or where they belong.
          </p>
        </Note>

        <Note mark="n = 1" markUnit="networks tested" heading="One network, one topology">
          <p>
            Every result comes from a single 22-junction benchmark. Being a real published network beats a synthetic
            toy, but it is still one topology at one scale. Nothing here demonstrates that the behaviour holds at city
            scale, across different pipe-material mixes, or on networks with pumps and valves running on schedules.
          </p>
        </Note>

        <Note mark="gpm" markUnit="leak model unit" heading="The leak model is a simplification">
          <p>
            Leaks are injected as added demand at a junction. Real leaks occur along pipes, vary with pressure, and
            change over time. Emitter-based modelling sits closer to the physics but saturates badly in this solver, so
            we took the tractable simplification and are naming it.
          </p>
        </Note>

        <Note mark="fixture" markUnit="demo posteriors" heading="The demo data is synthetic">
          <p>
            On the live diagnosis screen the topology, coordinates, pipe connectivity and gauge positions are read
            straight from the real network file. The posteriors are synthetic, calibrated to match measured behaviour.
            That screen carries a Fixture badge for exactly this reason, and the badge clears itself once real
            evaluation output replaces the file.
          </p>
        </Note>

        <Note mark="open" markUnit="what would settle it" heading="What would change our minds">
          <p>
            A forward model where adding gauges improves accuracy would remove the central objection. So would
            reproducing the crossover on a second network with real gauge placement. Until one of those lands, the
            defensible claim stays narrow: a calibrated credible set, and fewer crews sent to reach it.
          </p>
        </Note>
      </DocPage>
      <Leva hidden />
    </>
  );
}
