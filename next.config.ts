import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // S3/CDN URL for /_next/static/* assets (JS, CSS chunks).
  // Set NEXT_PUBLIC_ASSET_PREFIX=https://bucket.s3.region.amazonaws.com in CI.
  assetPrefix: process.env.NEXT_PUBLIC_ASSET_PREFIX ?? "",
};

export default nextConfig;
