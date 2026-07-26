"use client";

import Link from "next/link";
import { GL } from "./gl";
import { Pill } from "./pill";
import { Button } from "./ui/button";
import { useState } from "react";

export function Hero() {
  const [hovering, setHovering] = useState(false);
  return (
    <div className="flex flex-col h-svh justify-center">
      <GL hovering={hovering} />

      <div className="text-center relative">
        <Pill className="mb-6">22 JUNCTIONS · 43 PIPES · 8 GAUGES</Pill>
        <h1 className="text-5xl sm:text-6xl md:text-7xl font-sentient">
          Find the leak <br />
          without <i className="font-light">guessing</i>
        </h1>
        <p className="font-mono text-sm sm:text-base text-foreground/80 [text-shadow:0_1px_12px_rgba(0,7,15,0.85)] text-balance mt-8 max-w-[520px] mx-auto">
          Bayesian leak localisation over live pressure gauges. We report a credible set and the bits we are still
          missing, never a single pipe we cannot prove.
        </p>

        <Link className="contents max-sm:hidden" href="/dashboard">
          <Button
            className="mt-14"
            onMouseEnter={() => setHovering(true)}
            onMouseLeave={() => setHovering(false)}
          >
            [Run A Diagnosis]
          </Button>
        </Link>
        <Link className="contents sm:hidden" href="/dashboard">
          <Button
            size="sm"
            className="mt-14"
            onMouseEnter={() => setHovering(true)}
            onMouseLeave={() => setHovering(false)}
          >
            [Run A Diagnosis]
          </Button>
        </Link>
      </div>
    </div>
  );
}
