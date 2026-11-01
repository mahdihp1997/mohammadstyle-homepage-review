import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  fullyParallel: false,
  workers: 1,
  timeout: 60_000,
  reporter: [["list"], ["json", { outputFile: "artifacts/codex-playwright-results.json" }]],
  use: {
    baseURL: "http://127.0.0.1:3000",
    browserName: "chromium",
    channel: process.env.PLAYWRIGHT_CHANNEL || undefined,
    reducedMotion: "reduce",
    locale: "fa-IR",
    deviceScaleFactor: 1,
    trace: "retain-on-failure",
  },
  projects: [
    { name: "desktop", use: { viewport: { width: 1440, height: 900 } } },
    { name: "tablet", use: { viewport: { width: 1024, height: 768 } } },
    { name: "mobile", use: { viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true } },
    { name: "mobile-small", use: { viewport: { width: 375, height: 812 }, hasTouch: true, isMobile: true } },
  ],
  webServer: {
    command: "npm run dev -- --hostname 127.0.0.1",
    url: "http://127.0.0.1:3000",
    reuseExistingServer: !process.env.CI,
    env:{MS_PRODUCT_ENABLED:'0',MS_PRIVATE_REVIEW_ASSETS:'1',MS_NEXT_DIST_DIR:'.next-review'},
    timeout: 120_000,
  },
});
