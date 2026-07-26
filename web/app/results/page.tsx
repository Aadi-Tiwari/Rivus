"use client";

import { Callout, DocPage, Note, Readout } from "@/components/doc-page";
import { Leva } from "leva";

export default function ResultsPage() {
  return (
    <>
      <DocPage
        sheet="Sheet 02 / Results"
        title={
          <>
            Reported
            <br />
            <i className="font-light">as measured</i>
          </>
        }
        lede="Every figure below came out of a run. Where an arm failed to beat its control, the row says so and stays in the table."
        meta={["66 incidents per arm", "chance 4.5%", "model σ 1.30", "roughness CV 0.10"]}
      >
        <Note mark="4" markUnit="arms, one control" heading="The four-arm table">
          <p>
            The random control is included because removing it would make every other row unreadable. Three of the four
            arms land on 1/22.
          </p>
          <Readout
            head={["arm", "exact", "top 5", "hops", "probes"]}
            rows={[
              ["random control", "7.6%", "31.8%", "2.09", "3.0"],
              ["max information gain", "4.5%", "27.3%", "2.18", "3.0"],
              ["adaptive stopping", "4.5%", "22.7%", "2.18", "1.0"],
              ["all 8 gauges", "4.5%", "30.3%", "2.18", "8.0"],
            ]}
            mark={2}
            caption="Chance on 22 junctions is 4.5%."
          />
          <Callout tone="warn">
            The treatment arms did not beat the control in this regime. Random at 7.6% is noise above chance, not a win
            for randomness.
          </Callout>
          <p>
            The diagnostic that explains it: reading all 8 gauges is no better than reading 3 at random. When more data
            stops helping, the forward model is misspecified rather than the policy being poor.
          </p>
        </Note>

        <Note mark="3 → 1" markUnit="crew dispatches" heading="The result that did survive">
          <p>
            Adaptive stopping spent 1.0 probes against 3.0 while landing in the same accuracy band. In a regime where
            arms separate on accuracy that is the result worth having: comparable answers for a third of the callouts.
          </p>
          <Callout>
            Each probe is a crew sent to a street. Cutting three dispatches to one is the claim Rivus makes, and it is
            the only claim here that survived measurement.
          </Callout>
        </Note>

        <Note mark="0.04" markUnit="CV crossover" heading="The tension we did not hide">
          <p>
            The non-circularity gate and the accuracy pull against each other. Sweeping roughness perturbation strength,
            66 incidents per row:
          </p>
          <Readout
            head={["roughness CV", "exact", "top 5", "median divergence", "gate pass"]}
            rows={[
              ["0.00", "40.9%", "80.3%", "0.341", "32%"],
              ["0.02", "34.8%", "75.8%", "0.346", "36%"],
              ["0.04", "13.6%", "45.5%", "0.490", "70%"],
              ["0.06", "4.5%", "31.8%", "0.706", "100%"],
              ["0.10", "4.5%", "30.3%", "1.294", "100%"],
            ]}
            mark={2}
            caption="The crossover near CV 0.04 is the defensible operating point: 13.6% exact, three times chance, gate passing 70% of the time."
          />
          <p>
            The system beats chance only where the gate fails, and passes the gate only where the system stops working.
            Quoting the top rows while running the bottom ones would be the easiest way to lie with this table, so both
            columns stay.
          </p>
        </Note>

        <Note mark="91" markUnit="% coverage at 90%" heading="Calibration">
          <p>
            The 90% credible set contains the true junction about 91% of the time. Sharper posteriors read better on a
            screen but under-cover, and an interval advertising 90% while delivering 56% is worse than publishing no
            interval at all.
          </p>
        </Note>
      </DocPage>
      <Leva hidden />
    </>
  );
}
