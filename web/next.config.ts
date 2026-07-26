import type { NextConfig } from "next";

const nextConfig: NextConfig = {
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
