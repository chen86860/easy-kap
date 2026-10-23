import { fileURLToPath, URL } from "node:url";
import { defineConfig } from "vitest/config";

// Kept apart from vite.config.ts: the Cloudflare and router plugins only make sense for the app build.
export default defineConfig({
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  test: { include: ["src/**/*.test.ts"] },
});
