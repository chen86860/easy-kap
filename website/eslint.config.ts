import js from "@eslint/js";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import { defineConfig, globalIgnores } from "eslint/config";
import globals from "globals";
import tseslint from "typescript-eslint";

export default defineConfig([
  globalIgnores(["dist", ".wrangler", "src/routeTree.gen.ts"]),
  {
    files: ["**/*.{ts,tsx}"],
    extends: [js.configs.recommended, tseslint.configs.recommended, reactHooks.configs.flat.recommended, reactRefresh.configs.vite],
    languageOptions: { globals: globals.browser },
  },
  {
    // Route files export a `Route` object alongside their component, which the router plugin handles.
    files: ["src/routes/**/*.tsx", "src/components/ui/**/*.tsx"],
    rules: { "react-refresh/only-export-components": "off" },
  },
]);
