// Copyright © Cartoway
// Visual regression: Lookbook previews (Bootstrap 5 + v2 overrides). Snapshots are Linux CI baselines.

import { defineConfig, devices } from '@playwright/test'

const repoRoot = '..'
const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://127.0.0.1:3001'

// `config/database.yml` uses POSTGRES_HOST; when unset, the pg adapter uses a Unix socket
// (`/var/run/postgresql/.s.PGSQL.5432`). Rails merges DATABASE_URL when set (CI + local Docker).
const databaseUrl =
  process.env.DATABASE_URL ??
  (process.env.CI
    ? 'postgres://rails:password@localhost:5432/rails_test'
    : 'postgres://rails:password@127.0.0.1:5433/rails_test')

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: process.env.CI ? [['html', { open: 'never' }], ['list']] : [['list']],
  use: {
    baseURL,
    ...devices['Desktop Chrome'],
    colorScheme: 'light',
    viewport: { width: 1280, height: 900 },
    // Stable sans-serif stack; Montserrat may still load from Google (small drift possible).
    launchOptions: {
      args: ['--font-render-hinting=none', '--disable-lcd-text']
    }
  },
  expect: {
    toHaveScreenshot: {
      maxDiffPixels: 120,
      animations: 'disabled',
      caretColor: 'transparent'
    }
  },
  // Do not use `rails assets:clobber` here: webpacker hooks require Yarn and can exit 1 after
  // clearing public/assets, leaving Playwright on a stale Puma (wrong CSS). See bin/lookbook-vrt-server.
  webServer: process.env.PLAYWRIGHT_SKIP_WEBSERVER
    ? undefined
    : {
        command: 'bin/lookbook-vrt-server',
        cwd: repoRoot,
        env: {
          ...process.env,
          RAILS_ENV: 'test',
          DATABASE_URL: databaseUrl,
          PORT: '3001',
          HOST: '127.0.0.1',
          DISABLE_SPRING: '1'
        },
        url: `${baseURL}/lookbook`,
        reuseExistingServer: process.env.PLAYWRIGHT_REUSE_SERVER === '1',
        timeout: 300_000,
        stdout: 'pipe',
        stderr: 'pipe'
      }
})
