"use client";

import { Dashboard } from "@/components/dashboard";
import { Leva } from "leva";

export default function DashboardPage() {
  return (
    <>
      <Dashboard />
      <Leva hidden />
    </>
  );
}
