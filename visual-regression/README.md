# Lookbook — visual regression (Playwright)

Screenshots of each Lookbook preview in **headless Chromium**, compared to reference PNGs in `tests/lookbook.vrt.spec.ts-snapshots/` (suffix **`linux`** = baseline generated on Ubuntu, same as CI).

## Local prerequisites

- Ruby / Bundler, same as the rest of the project
- PostgreSQL reachable for `RAILS_ENV=test` (Playwright sets `DATABASE_URL` by default to `postgres://rails:password@127.0.0.1:5433/rails_test` — same as the optional `pg-playwright-test` Docker container on host port **5433**; CI uses **5432** on `localhost`)
- `yarn` + root dependencies (Webpacker, to match CI)
- Node **≥ 18** for Playwright
- Do **not** leave `PLAYWRIGHT_SKIP_WEBSERVER=1` set unless you start Rails yourself on port **3001** with `RAILS_ENV=test`

Example local Postgres (once):

```bash
docker run -d --name pg-playwright-test -p 5433:5432 \
  -e POSTGRES_USER=rails -e POSTGRES_PASSWORD=password -e POSTGRES_DB=rails_test \
  postgis/postgis:15-3.5
export RAILS_ENV=test
bin/rails db:setup   # once, against DATABASE_URL above
```

## Updating references (after an intentional UI change)

Previews load v2 overrides (e.g. `.btn-secondary` / `.btn-light` in `app/assets/stylesheets/v2/_visual_language.scss`). If you change tokens or Bootstrap styles, CI will fail until PNGs are regenerated: Playwright **expected** is the file under `lookbook.vrt.spec.ts-snapshots/`, **received** is the current Chromium render.

### Devcontainer (port 8080) vs Playwright (port 3001)

| | Devcontainer `http://localhost:8080/lookbook` | Playwright VRT |
|---|-----------------------------------------------|----------------|
| **Environment** | `RAILS_ENV=production` (docker-compose default) | `RAILS_ENV=test` |
| **v2 CSS** | Assets **precompiled in the Docker image** (`assets:precompile` at build) | Sprockets **recompiles** from the workspace (`layout_bootstrap_overrides` + imports) |
| **Port** | 8080 (Puma in the container) | 3001 (Playwright `webServer`) |

These are **not** the same process or asset pipeline. A correct Lookbook on **8080** does not guarantee valid snapshots on **3001**.

### Bootstrap-only screenshots (stale server)

Symptoms: grey `btn-secondary`, no Cartoway tokens.

Common causes:

1. **Stale Puma on port 3001** — stop it or avoid `PLAYWRIGHT_REUSE_SERVER=1` unless you restarted Rails after changing CSS.
2. **Webpacker not compiled** — run `NODE_ENV=test bin/rails webpacker:compile` at the repo root (same as CI) before Playwright.

Playwright’s `webServer` starts **`bundle exec rails server`** on port 3001 (`RAILS_ENV=test`). It does not run `assets:clobber` (Webpacker can fail without Yarn after clearing `public/assets/`).

To target the container (snapshots = Docker render, not the CI test job):

```bash
PLAYWRIGHT_SKIP_WEBSERVER=1 PLAYWRIGHT_BASE_URL=http://localhost:8080 npx playwright test --update-snapshots
```

To match CI, regenerate with the default Playwright server (port 3001) after `yarn install` at the repository root.

At the repository root:

```bash
export RAILS_ENV=test
export DATABASE_URL=postgres://…/rails_test   # adjust as needed
yarn install
NODE_ENV=test bin/rails webpacker:compile
bin/rails db:setup
```

Then, in another terminal:

```bash
cd visual-regression
npm ci
npx playwright install chromium
PLAYWRIGHT_SKIP_WEBSERVER=1 npx playwright test --update-snapshots   # if Rails is already running on port 3001
# or: let Playwright start Rails (omit PLAYWRIGHT_SKIP_WEBSERVER)
npx playwright test --update-snapshots
```

Commit the files under `tests/lookbook.vrt.spec.ts-snapshots/*.png`.

**Important:** regenerate snapshots on **Linux** (or the same image as GitHub Actions) to avoid macOS ↔ Linux drift described in [this article](https://medium.com/@haleywardo/streamlining-playwright-visual-regression-testing-with-github-actions-e077fd33c27c).

### Typography drift (e.g. `≥` on `grid_layout-rows_and_columns`)

The preview text is `≥576px` in HTML — **no space character** between `≥` and the digits. Any gap you see on CI comes from **Montserrat** glyph metrics (side-bearing), not from extra markup.

If Montserrat from Google Fonts is not loaded before the screenshot, Chromium uses a **system fallback** (`system-ui`, etc.): the `≥` often looks **smaller** and **tighter** against the following digits (no apparent space). CI runners usually fetch Google Fonts reliably during `npx playwright install --with-deps` + the test run.

Tests call `waitForLookbookFonts()` after stylesheets load to force Montserrat before `toHaveScreenshot`. If that throws locally, fix network access to `fonts.googleapis.com` or regenerate baselines on CI.

## CI

The `lookbook_visual` job in `.github/workflows/rubyonrails.yml` runs `npx playwright test`. On failure, the HTML report is published as the `lookbook-playwright-report` artifact.

## Adding a preview

Extend the `LOOKBOOK_PREVIEWS` array in `tests/lookbook.vrt.spec.ts` (paths `/lookbook/preview/...`), then regenerate snapshots.
