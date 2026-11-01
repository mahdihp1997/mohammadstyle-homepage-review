import type { NextConfig } from "next";
const distDir=process.env.MS_NEXT_DIST_DIR??'.next';
if(!['.next','.next-review','.next-production'].includes(distDir))throw Error('Unknown build directory');
const nextConfig: NextConfig = { reactStrictMode: true, devIndicators: false, poweredByHeader:false, distDir, output:'standalone' };
export default nextConfig;
