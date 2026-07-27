"use client";

import { Sheet } from "@/components/doc-render";
import { Leva } from "leva";

export default function ResultsPage() {
  return (
    <>
      <Sheet id="results" />
      <Leva hidden />
    </>
  );
}
