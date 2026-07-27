"use client";

import { Callout, DocPage, Expr, Note, Readout } from "@/components/doc-page";
import docs from "@/generated/docs.json";

/**
 * Renders one written sheet from the data jac/docs.jac emits. The prose and the
 * structure live there; this file only maps block kinds onto the report components,
 * so a wording change is a Jac change and never a React one.
 */

type Block = {
  p?: string;
  callout?: string;
  tone?: string;
  expr?: string;
  readout?: { head: string[]; rows: string[][]; mark?: number; caption?: string };
};

// Asterisks mark the italic run in a title line, which is the only inline styling
// any sheet needs. Odd segments are inside a pair.
function italics(line: string) {
  return line.split("*").map((seg, i) =>
    i % 2 === 1 ? (
      <i key={i} className="font-light">
        {seg}
      </i>
    ) : (
      seg
    )
  );
}

function block(b: Block, key: number) {
  if (b.readout) return <Readout key={key} {...b.readout} />;
  if (b.expr) return <Expr key={key}>{b.expr}</Expr>;
  if (b.callout) {
    return (
      <Callout key={key} tone={b.tone === "warn" ? "warn" : undefined}>
        {b.callout}
      </Callout>
    );
  }
  return <p key={key}>{b.p}</p>;
}

export function Sheet({ id }: { id: keyof typeof docs }) {
  const d = docs[id];
  return (
    <DocPage
      sheet={d.sheet}
      title={d.title.map((line, i) => (
        <span key={i}>
          {i > 0 && <br />}
          {italics(line)}
        </span>
      ))}
      lede={d.lede}
      meta={d.meta}
    >
      {d.notes.map((n, i) => (
        <Note key={i} mark={n.mark} markUnit={n.markUnit} heading={n.heading}>
          {(n.blocks as Block[]).map(block)}
        </Note>
      ))}
    </DocPage>
  );
}
