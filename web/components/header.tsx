"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Logo } from "./logo";
import { MobileMenu } from "./mobile-menu";

// Overview is the home page itself, so it is not a nav item. The live demo has a
// CTA on every page, so it is not one either.
const NAV = [
  { label: "Method", href: "/method" },
  { label: "Results", href: "/results" },
  { label: "Limits", href: "/limits" },
];

export const Header = () => {
  const pathname = usePathname();

  // The dashboard carries its own command bar, so the marketing header would sit
  // on top of it.
  if (pathname?.startsWith("/dashboard")) return null;

  return (
    <div className="fixed z-50 pt-8 md:pt-12 top-0 left-0 w-full">
      <header className="flex items-center justify-between container">
        <Link href="/">
          <Logo className="w-[150px] md:w-[180px]" />
        </Link>
        <nav className="flex max-lg:hidden items-center justify-center gap-x-10">
          {NAV.map((item) => {
            const active = pathname === item.href;
            return (
              <Link
                className={`uppercase inline-block font-mono duration-150 transition-colors ease-out ${
                  active ? "text-primary" : "text-foreground/60 hover:text-foreground/100"
                }`}
                href={item.href}
                key={item.label}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
        <MobileMenu />
      </header>
    </div>
  );
};
