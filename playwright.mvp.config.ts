import { defineConfig } from "@playwright/test";
// Cold Next.js development compilation and the fixed upstream timeout are included.
export default defineConfig({
  testDir: "./tests-mvp",
  fullyParallel: false,
  workers: 1,
  timeout: 120000,
  expect: { timeout: 15000 },
  reporter: [
    ["list"],
    ["json", { outputFile: "backend/.local/mvp/results/ui-raw.json" }],
  ],
  use: {
    baseURL: "http://127.0.0.1:3000",
    browserName: "chromium",
    channel: process.env.PLAYWRIGHT_CHANNEL || undefined,
    reducedMotion: "reduce",
    locale: "fa-IR",
    deviceScaleFactor: 1,
    actionTimeout: 20000,
    trace: "off",
  },
  projects: [
    { name: "desktop", use: { viewport: { width: 1440, height: 900 } } },
    { name: "tablet", use: { viewport: { width: 1024, height: 768 } } },
    {
      name: "mobile",
      use: {
        viewport: { width: 390, height: 844 },
        isMobile: true,
        hasTouch: true,
      },
    },
    {
      name: "mobile-small",
      use: {
        viewport: { width: 375, height: 812 },
        isMobile: true,
        hasTouch: true,
      },
    },
  ],
  webServer: {
    command: "npm run dev -- --hostname 127.0.0.1",
    url: "http://127.0.0.1:3000",
    reuseExistingServer: !process.env.CI,
    env: {
      MS_MVP_ENABLED: "1",
      MS_BOOKING_SERVER_ENABLED: "1",
      MS_BOOKING_SERVER_PROFILE: "mvp-local",
    },
    timeout: 120000,
  },
});
