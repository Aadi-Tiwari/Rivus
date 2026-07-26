"use client";

import Link from "next/link";
import { GL } from "./gl";

/**
 * Report-sheet layout for the written pages.
 *
 * The signature is the left measurement rail: every marginal note is a real
 * governing quantity from the section beside it, so the structure carries
 * information rather than decorating the page. Nothing here is a card, because
 * a stack of identical rounded boxes flattens the hierarchy it pretends to make.
 */

export function DocPage({
  sheet,
  title,
  lede,
  meta,
  children,
}: {
  sheet: string;
  title: React.ReactNode;
  lede: string;
  meta: string[];
  children: React.ReactNode;
}) {
  return (
    <div className="relative min-h-svh">
      <GL hovering={false} />
      <div className="fixed inset-0 bg-[#00070F]/90 pointer-events-none" />

      <div className="relative z-10 container pt-36 md:pt-44 pb-28 max-w-[1000px]">
        {/* Masthead, set like the header block of a survey sheet */}
        <div className="grid grid-cols-1 md:grid-cols-[100px_1fr] gap-x-8">
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-[var(--belief)] pt-3">{sheet}</div>
          <div>
            <h1 className="font-sentient text-[2.6rem] md:text-[4rem] leading-[0.95] tracking-[-0.02em] text-white">
              {title}
            </h1>
            <p className="font-mono text-[13px] text-white/55 leading-[1.75] mt-7 max-w-[54ch]">{lede}</p>
          </div>
        </div>

        <div className="mt-10 pt-3 border-t border-white/[0.14] grid grid-cols-1 md:grid-cols-[100px_1fr] gap-x-8">
          <div />
          <dl className="flex flex-wrap gap-x-8 gap-y-1.5 font-mono text-[10px] uppercase tracking-[0.14em] text-white/35">
            {meta.map((m) => (
              <dd key={m}>{m}</dd>
            ))}
          </dl>
        </div>

        <div className="mt-14">{children}</div>

        <div className="mt-20 pt-5 border-t border-white/[0.14] grid grid-cols-1 md:grid-cols-[100px_1fr] gap-x-8">
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-white/25 pt-0.5">End</div>
          <div className="flex flex-wrap items-center gap-x-7 gap-y-2 font-mono text-[12px]">
            <Link
              href="/dashboard"
              className="text-[var(--belief)] border-b border-[var(--belief)]/40 hover:border-[var(--belief)] pb-0.5 transition-colors duration-200"
            >
              Open the live diagnosis
            </Link>
            <Link href="/method" className="text-white/45 hover:text-white/80 transition-colors duration-200">
              Method
            </Link>
            <Link href="/results" className="text-white/45 hover:text-white/80 transition-colors duration-200">
              Results
            </Link>
            <Link href="/limits" className="text-white/45 hover:text-white/80 transition-colors duration-200">
              Limits
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}

/**
 * One section. `mark` is the section's governing quantity, printed in the rail.
 * It must be a real number or verdict from the prose beside it, never a label.
 */
export function Note({
  mark,
  markUnit,
  heading,
  children,
}: {
  mark: string;
  markUnit?: string;
  heading: string;
  children: React.ReactNode;
}) {
  return (
    <section className="grid grid-cols-1 md:grid-cols-[100px_1fr] gap-x-8 py-9 border-t border-white/[0.09] first:border-t-0 first:pt-0">
      <div className="max-md:mb-4 md:text-right md:pt-1.5">
        <div className="font-mono text-[15px] tabular-nums text-[var(--belief)] leading-none">{mark}</div>
        {markUnit && (
          <div className="font-mono text-[9px] uppercase tracking-[0.16em] text-white/30 mt-1.5 leading-tight">
            {markUnit}
          </div>
        )}
      </div>
      <div>
        <h2 className="font-sentient text-[1.6rem] leading-tight text-white mb-4">{heading}</h2>
        <div className="space-y-4 font-mono text-[13px] leading-[1.8] text-white/60 max-w-[62ch]">{children}</div>
      </div>
    </section>
  );
}

/** A spec note. Hanging rule, no tinted box, no rounded corners. */
export function Callout({ children, tone }: { children: React.ReactNode; tone?: "warn" }) {
  const rule = tone === "warn" ? "border-[var(--critical)]" : "border-[var(--belief)]";
  const text = tone === "warn" ? "text-[var(--critical)]/85" : "text-white/80";
  return (
    <p className={`border-l-2 ${rule} pl-5 py-1 font-mono text-[13px] leading-[1.8] ${text}`}>{children}</p>
  );
}

/** A quantity set on its own line, the way a report calls out a measured value. */
export function Expr({ children }: { children: React.ReactNode }) {
  return (
    <p className="font-mono text-[13px] text-[var(--foam)] bg-white/[0.03] border-y border-white/[0.08] px-5 py-3.5 -mx-1">
      {children}
    </p>
  );
}

/** Instrument readout, not a card. Ruled rows, tabular figures, marked row. */
export function Readout({
  head,
  rows,
  mark,
  caption,
}: {
  head: string[];
  rows: (string | number)[][];
  mark?: number;
  caption?: string;
}) {
  return (
    <figure className="my-1">
      <div className="overflow-x-auto">
        <table className="w-full font-mono text-[12px] tabular-nums min-w-[440px] border-collapse">
          <thead>
            <tr className="text-white/30 text-[9px] uppercase tracking-[0.16em]">
              {head.map((h, i) => (
                <th key={h} className={`font-normal pb-2 pl-3 ${i === 0 ? "text-left" : "text-right"}`}>
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((r, ri) => {
              const marked = ri === mark;
              return (
                <tr key={ri} className="border-t border-white/[0.08]">
                  {r.map((c, ci) => (
                    <td
                      key={ci}
                      className={`py-2.5 pl-3 ${ci === 0 ? "text-left" : "text-right"} ${
                        marked ? "text-[var(--belief)]" : "text-white/65"
                      } ${
                        ci === 0 && marked
                          ? "relative before:absolute before:left-0 before:top-1/2 before:-translate-y-1/2 before:h-3.5 before:w-[2px] before:bg-[var(--belief)]"
                          : ""
                      }`}
                    >
                      {c}
                    </td>
                  ))}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      {caption && (
        <figcaption className="font-mono text-[11px] leading-relaxed text-white/35 mt-3 pt-3 border-t border-white/[0.08]">
          {caption}
        </figcaption>
      )}
    </figure>
  );
}
