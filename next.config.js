/** @type {import('next').NextConfig} */
const nextConfig = {
  async rewrites() {
    return [{ source: "/api/health", destination: "/api/healthz" }];
  },
};
module.exports = nextConfig;
