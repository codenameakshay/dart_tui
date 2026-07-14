/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    // GIFs are served as static assets from /public; no optimization needed.
    unoptimized: true,
  },
};

export default nextConfig;
