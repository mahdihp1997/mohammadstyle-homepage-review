import { defineConfig } from "@playwright/test";
import base from "./playwright.mvp.config";
export default defineConfig({ ...base, testDir: "./tests-login", outputDir: "./backend/.local/mvp/playwright-output/login", reporter: [
  ["list"], ["json", { outputFile: "backend/.local/mvp/results/login-ui.json" }],
] });
