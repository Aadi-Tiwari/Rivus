"""Where does information-gain probing actually beat random probing?

The lift depends on how well the utility knows today's demand. A district metered area
has a flow meter at its inlet, so consumption is partly observed rather than unknown --
which is why the default sits at 0.12 rather than at raw day-to-day swing.

This sweeps that uncertainty and reports the lift over a random control at each point,
instead of picking one setting and hoping. One seed per location, 35 incidents per
point, so read it as a trend and not a precise figure: the headline table in
evaluate.jac runs three seeds and still cannot resolve the difference from zero.

    jac run jac/envelope.jac
"""

include harness;


glob CVS: list = [0.05, 0.08, 0.12, 0.18, 0.25];


with entry {
    for n in [root-->] { del n; }
    root spawn IngestNetwork();
    root spawn BuildForwardModel();

    print(f"\n  gauge noise {GAUGE_NOISE} psi - lift measured against a random control\n");
    print(f"  demand CV | mismatch | gate | info hops | random hops |  lift  | info top-5");
    for cv in CVS {
        mis = 0.0; ih = 0.0; rh = 0.0; it5 = 0; k = 0;
        for (i, t) in enumerate(NODES) {
            root spawn StageIncident(truth=t, seed=1000 + i, demand_cv=cv);
            g = root spawn CheckNonCircularity(truth=t);
            mis += g.median;
            a = root spawn RunArm(truth=t, arm="info");
            ih += a.hops;
            if a.rank <= 5 { it5 += 1; }
            # restage so the random arm faces the same incident, not a consumed one
            root spawn StageIncident(truth=t, seed=1000 + i, demand_cv=cv);
            b = root spawn RunArm(truth=t, arm="random");
            rh += b.hops;
            k += 1;
        }
        gate = "fail";
        if mis / k > GAUGE_NOISE { gate = "PASS"; }
        lift = (1.0 - (ih / k) / (rh / k)) * 100.0;
        print(f"     {cv:.2f}   |  {mis/k:.3f}  | {gate} |   {ih/k:.2f}    |    {rh/k:.2f}     "
              f"| {lift:+.0f}%  |   {100.0*it5/k:.0f}%");
    }
    print(f"\n  The gate asks whether the evidence departs from the forward model by more");
    print(f"  than gauge noise. It only passes at high demand uncertainty - where the");
    print(f"  method has no measurable advantage left. That tension is the honest result.");
}
