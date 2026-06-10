import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Static export — produces out/ directory served by Apache via /var/www/html/
  output: "export",
};

export default nextConfig;
