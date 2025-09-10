/** @type {import('next').NextConfig} */
const nextConfig = {
  env: {
    NEXT_PUBLIC_SOCKET_URL: process.env.SOCKET_SERVER_URL || '',
  },
};
export default nextConfig;
