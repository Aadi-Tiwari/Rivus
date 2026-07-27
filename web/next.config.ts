import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Fully static output: every page is a client component reading a static JSON, so the
  // app needs no Node runtime and can be hosted by any plain file server.
  output: "export",
  // Emits dashboard/index.html instead of dashboard.html, so a plain file server
  // resolves /dashboard without a rewrite rule. Without it the deploy link 404s.
  trailingSlash: true,
  // No `eslint` key: Next 16 dropped it, and leaving it in made every build print an
  // invalid-config warning.
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
