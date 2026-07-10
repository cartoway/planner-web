# Lookbook — visual regression (Playwright)

Screenshots of each Lookbook preview in **headless Chromium**, compared to reference PNGs in `tests/lookbook.vrt.spec.ts-snapshots/` (suffix **`linux`** = baseline generated on Ubuntu, same as CI).

## When to update snapshots

**No** — you do not need to touch `visual-regression/` on every merged change. CI only runs these tests when the `lookbook_visual` job runs (see `.github/workflows/rubyonrails.yml`).

Update reference PNGs **only** when you **intentionally** change something that affects how a covered Lookbook preview renders in Chromium:

| Update snapshots | Examples |
|------------------|----------|
| **Yes** | SCSS/CSS (v2 tokens, Bootstrap overrides, `layout_bootstrap_overrides`), ViewComponent or HAML used by a Lookbook preview, preview fixture data, fonts, spacing, colours |
| **Yes** | New preview added to `LOOKBOOK_PREVIEWS` in `tests/lookbook.vrt.spec.ts` |
| **No** | Backend, API, models, mailers, unrelated pages (login, planning, unsupported browser, etc.) |
| **No** | Refactors with no visual change (rename, extract method, tests only) |
| **No** | Devcontainer on port **8080** only — that stack is separate from Playwright (see below) |

**Workflow after a validated visual change:**

1. Finish the UI change and review it in Lookbook (`/lookbook`).
2. Regenerate snapshots locally (commands below) — prefer **Linux** (same as CI).
3. Open the diff on `tests/lookbook.vrt.spec.ts-snapshots/*.png` and confirm differences match what you intended.
4. Commit the updated PNGs **in the same PR** as the UI change.

If CI fails on `lookbook_visual` with a screenshot mismatch, either fix an accidental regression or regenerate baselines with `--update-snapshots` and commit.

## Reviewing diffs locally

Use this flow **before** running `--update-snapshots`: compare the current render to committed baselines and decide whether each difference is intentional.

### 1. Prerequisites

Same as [Quick commands](#quick-commands-match-ci) (Postgres test DB, `yarn install`, `webpacker:compile`, `db:setup`). Playwright uses port **3001** (`RAILS_ENV=test`), not the devcontainer on **8080**.

Optional eyeball check on the devcontainer (`http://localhost:8080/lookbook`) is useful, but VRT validation must go through Playwright — different env and asset pipeline.

### 2. Run tests without updating baselines

```bash
cd visual-regression
npm ci
npx playwright install chromium
npx playwright test --reporter=html,list
```

- **All green** → no snapshot update needed.
- **Failures** → screenshot mismatch; continue below.

### 3. Open the Playwright HTML report (recommended)

```bash
cd visual-regression
npx playwright show-report
```

Opens `http://localhost:9323` (default). For each failed test, open the screenshot attachment: Playwright shows **expected** (committed baseline), **actual** (current render), and **diff** (highlighted pixels).

The report is written to `visual-regression/playwright-report/` (gitignored).

### 4. Or inspect raw PNGs in `test-results/`

If you prefer files or the report did not open:

```bash
find visual-regression/test-results -name '*-diff.png' -o -name '*-actual.png'
```

Each failure folder contains `-expected.png`, `-actual.png`, and `-diff.png`.

### 5. Validate and accept (or reject) the change

| Outcome | Action |
|---------|--------|
| Diff is a **regression** (unintended) | Fix CSS/components, re-run step 2 until green |
| Diff is **intentional** | Update baselines (see below), then re-run step 2 to confirm green |

Update one preview:

```bash
cd visual-regression
npx playwright test --update-snapshots -g 'lookbook: buttons-variants'
```

Update all changed previews:

```bash
npx playwright test --update-snapshots
```

Review committed baselines before pushing:

```bash
git diff visual-regression/tests/lookbook.vrt.spec.ts-snapshots/
```

Open changed PNGs in your editor or image viewer; confirm only the previews you meant to change moved.

### 6. Final check

```bash
cd visual-regression
npx playwright test
```

Commit updated `*-linux.png` files in the same PR as the UI change.

## From the devcontainer (Docker)

### Automatic run on dev stack startup

With `LOOKBOOK_VRT=1` in `.env`, `.devcontainer/compose.sh up` starts Playwright comparison:

1. **`lookbook-vrt`** — Playwright (Ubuntu image) compares snapshots against `web:3001` (`RAILS_ENV=test`).
2. **`lookbook-vrt-export`** — writes `public/lookbook-visual-regression/manifest.json` and PNG copies.

The **`web`** service starts a Rails **test** server on **3001** only when `LOOKBOOK_VRT=1` (for VRT). Puma stays on **8080**.

**View results in Lookbook:** [http://localhost:8080/lookbook/preview/design_system/visual_regression/report](http://localhost:8080/lookbook/preview/design_system/visual_regression/report)

When `LOOKBOOK_VRT=1`, failed rows in the Lookbook report show **Accept baseline** / **Accept all changes** buttons. Each action asks for confirmation, then copies `actual.png` to `visual-regression/tests/lookbook.vrt.spec.ts-snapshots/*-linux.png` on the host (via volume mount). Commit the updated PNGs.

Enable automatic VRT on startup: `LOOKBOOK_VRT=1` in `.env`, then `.devcontainer/compose.sh up --build`.

After the stack is up, wait until `lookbook-vrt-export` exits (`docker compose ps -a`), then open the URL above.

### Manual re-run from the host

The `web` image is **Alpine**: Playwright Chromium **does not run** inside `planner-dev exec web` (`spawn … ENOENT`). Use the helper script — same stack as above, with workspace bind-mount.

**Prerequisites:** dev stack running (web + db). Workspace is bind-mounted into the Playwright container so snapshot updates land in your git tree (unlike code baked into the `web` image at build time).

```bash
.devcontainer/visual-regression.sh test    # compare + export Lookbook report
.devcontainer/visual-regression.sh report  # http://127.0.0.1:9323 — Playwright HTML (optional)
.devcontainer/visual-regression.sh export  # re-export manifest only
.devcontainer/visual-regression.sh update  # accept intentional changes
.devcontainer/visual-regression.sh update -g 'lookbook: buttons-variants'   # single preview
```

Optional shell aliases are defined in `.devcontainer/aliases.sh`.

What the script does:

1. **`prepare`** (also run before `test` / `update`): `webpacker:compile` + `db:test:prepare` in `web`, then starts `rails server -e test -p 3001` in the background if needed.
2. **Playwright container**: `npm ci` + `npx playwright test` with `PLAYWRIGHT_BASE_URL=http://web:3001` on `public-network`.

Review diffs: run `.devcontainer/visual-regression.sh report`, or inspect `visual-regression/test-results/**/*-diff.png` on the host.

**Not recommended for baselines:** pointing Playwright at `http://web:8080` (production, precompiled assets). Useful only for a quick smoke check — snapshots would not match CI.

After UI changes in the devcontainer, **rebuild is not required** for VRT when using this script (live workspace mount). Rebuild the stack only to refresh what you see on port **8080**.

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

See [When to update snapshots](#when-to-update-snapshots) above for when this is required.

Previews load v2 overrides (e.g. `.btn-secondary` / `.btn-light` in `app/assets/stylesheets/v2/_visual_language.scss`). If you change tokens or Bootstrap styles, CI will fail until PNGs are regenerated: Playwright **expected** is the file under `lookbook.vrt.spec.ts-snapshots/`, **received** is the current Chromium render.

### Quick commands (match CI)

From the **repository root** (once per machine or after dependency changes):

```bash
export RAILS_ENV=test
export DATABASE_URL=postgres://rails:password@127.0.0.1:5433/rails_test   # or your test DB
yarn install
NODE_ENV=test bin/rails webpacker:compile
bin/rails db:setup
```

Then regenerate snapshots:

```bash
cd visual-regression
npm ci
npx playwright install chromium
npx playwright test --update-snapshots
```

Playwright starts Rails on port **3001** (`RAILS_ENV=test`). Commit every changed file under `tests/lookbook.vrt.spec.ts-snapshots/*.png`.

To update a **single** preview after a small change:

```bash
cd visual-regression
npx playwright test --update-snapshots -g 'lookbook: buttons-variants'
```

Replace `buttons-variants` with the `name` from `LOOKBOOK_PREVIEWS` in `tests/lookbook.vrt.spec.ts`.

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

If Rails is **already** running on port 3001:

```bash
cd visual-regression
PLAYWRIGHT_SKIP_WEBSERVER=1 npx playwright test --update-snapshots
```

**Important:** regenerate snapshots on **Linux** (or the same image as GitHub Actions) to avoid macOS ↔ Linux drift described in [this article](https://medium.com/@haleywardo/streamlining-playwright-visual-regression-testing-with-github-actions-e077fd33c27c).

### Typography drift (e.g. `≥` on `grid_layout-rows_and_columns`)

The preview text is `≥576px` in HTML — **no space character** between `≥` and the digits. Any gap you see on CI comes from **Montserrat** glyph metrics (side-bearing), not from extra markup.

If Montserrat from Google Fonts is not loaded before the screenshot, Chromium uses a **system fallback** (`system-ui`, etc.): the `≥` often looks **smaller** and **tighter** against the following digits (no apparent space). CI runners usually fetch Google Fonts reliably during `npx playwright install --with-deps` + the test run.

Tests call `waitForLookbookFonts()` after stylesheets load to force Montserrat before `toHaveScreenshot`. If that throws locally, fix network access to `fonts.googleapis.com` or regenerate baselines on CI.

## CI

The `lookbook_visual` job in `.github/workflows/rubyonrails.yml` runs `npx playwright test`. On failure, the HTML report is published as the `lookbook-playwright-report` artifact.

## Adding a preview

Extend the `LOOKBOOK_PREVIEWS` array in `tests/lookbook.vrt.spec.ts` (paths `/lookbook/preview/...`), then regenerate snapshots.
