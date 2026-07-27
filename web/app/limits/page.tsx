"use client";

import { Sheet } from "@/components/doc-render";
import { Leva } from "leva";

export default function LimitsPage() {
  return (
    <>
      <Sheet id="limits" />
      <Leva hidden />
    </>
  );
}
