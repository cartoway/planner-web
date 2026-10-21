# Devcontainer — Lookbook visual regression

Guide for validating UI changes in the local Docker stack. Full technical reference: [`visual-regression/README.md`](../visual-regression/README.md).

## Prerequisites

1. Copy the environment config:
   ```bash
   cp .devcontainer/.env.template .env
   ```
2. (Optional) Enable shell aliases:
   ```bash
   source .devcontainer/aliases.sh
   ```
3. Start the stack:
   ```bash
   planner-dev-up
   # or: .devcontainer/compose.sh up --build -d
   ```

## Two servers, two roles

| Port | Service | Role |
|------|---------|------|
| **8080** | Puma (`RAILS_ENV=production`) | Day-to-day app + Lookbook, precompiled assets |
| **3001** | Rails test (`RAILS_ENV=test`) | Playwright target — **same env as CI** |

Port 8080 is for browsing Lookbook by eye. **VRT validation** must go through Playwright on **3001** (test Webpacker, different pipeline from 8080).

## Enable VRT

In `.env` at the project root:

```bash
LOOKBOOK_VRT=1
```

Then restart the stack (`planner-dev-up`).

When `LOOKBOOK_VRT=1`:

- `web` also starts Rails test on **3001** (see `start-web.sh`)
- on `compose up`, the **`lookbook-vrt`** (Playwright) then **`lookbook-vrt-export`** (report export) services run once

With `LOOKBOOK_VRT=0` (default), those services exit immediately without running Playwright.

## View the report

After a run (automatic or manual):

**http://localhost:8080/lookbook/preview/design_system/visual_regression/report**

The report reads `public/lookbook-visual-regression/manifest.json` and PNGs copied from Playwright. Those files are mounted from the host:

- `visual-regression/` → snapshots (`*-linux.png`) + `test-results/`
- `public/lookbook-visual-regression/` → Lookbook report

## Validation workflow

### 1. Run the comparison

**Automatic** (if `LOOKBOOK_VRT=1` at startup):

```bash
planner-dev-up
docker compose -f .devcontainer/docker-compose.yml ps -a   # wait until lookbook-vrt-export is "exited"
```

**Manual** (stack already up):

```bash
planner-dev-vrt test
# or: .devcontainer/visual-regression.sh test
```

`test` prepares Rails on 3001, runs Playwright in the Ubuntu image (Chromium does not run in the Alpine `web` image), then exports the Lookbook report.

### 2. Review diffs

In the Lookbook report: **Expected** / **Actual** / **Diff** columns for each failing preview.

Playwright alternative (detailed HTML report):

```bash
planner-dev-vrt report   # http://127.0.0.1:9323
```

### 3. Decide

| Situation | Action |
|-----------|--------|
| Unintentional regression | Fix the CSS/component, re-run `planner-dev-vrt test` |
| Intentional visual change | Accept the new baseline (step 4) |

### 4. Accept a baseline (dev only)

On the Lookbook report, **Accept baseline** / **Accept all changes** buttons (if `LOOKBOOK_VRT=1`).

Confirmation is **two clicks** with a delay (same UX as delete on the V2 destinations list).

This:

1. copies `actual.png` to `visual-regression/tests/lookbook.vrt.spec.ts-snapshots/*-linux.png` on the host
2. cleans Playwright artefacts for that preview
3. re-exports the manifest (the row becomes **passed**)

**Commit** the changed PNGs in the same PR as the UI change.

### 5. Bulk update (command line)

Equivalent to Playwright “update snapshots”:

```bash
planner-dev-vrt update                              # all previews
planner-dev-vrt update -g 'lookbook: buttons-variants'   # one preview
```

Then check the git diff:

```bash
git diff visual-regression/tests/lookbook.vrt.spec.ts-snapshots/
```

## When to update snapshots?

**No** on every change. **Yes** only when you intentionally change how a covered preview looks (SCSS, HAML, Lookbook fixtures, a new preview in `LOOKBOOK_PREVIEWS`, etc.).

CI runs `test_backend`, `test_frontend`, and `lint` in parallel, then `lookbook_visual` if those pass (see `.github/workflows/rubyonrails.yml`).

## Useful commands

| Command | Description |
|---------|-------------|
| `planner-dev-up` | Build + start the stack |
| `planner-dev-test backend` / `frontend` | Partitioned Minitest (DB `planner-test` in `db`) |
| `planner-dev-vrt test` | Comparison + Lookbook report export |
| `planner-dev-vrt export` | Re-export the manifest without re-running Playwright |
| `planner-dev-vrt report` | Playwright HTML report |
| `planner-dev-vrt update` | Regenerate `*-linux.png` baselines |
| `planner-dev-vrt prepare` | Rails test :3001 only |

## Troubleshooting

**“No report yet”** — the manifest is missing. Run `planner-dev-vrt test` or check that `lookbook-vrt-export` finished without error (`docker logs devcontainer-lookbook-vrt-export-1`).

**Accept button inactive** — check `LOOKBOOK_VRT=1` in `.env` and restart `web`.

**JS / report template not updated** — the `web` image embeds code at build time; some VRT paths are volume-mounted. When in doubt: `planner-dev-up --build`, or use `planner-dev-vrt` (full workspace mount for Playwright).

**Snapshots accepted on the host but report unchanged** — re-run `planner-dev-vrt export`; accept normally triggers an automatic re-export.

## Architecture (Docker services)

```
web:8080          → Puma production (Lookbook navigation)
web:3001          → Rails test (Playwright target, if LOOKBOOK_VRT=1)
lookbook-vrt      → Playwright (Ubuntu image), one-shot on up
lookbook-vrt-export → ruby script/export_lookbook_visual_regression_report.rb
```

Playwright **does not run** under `docker exec web` (Alpine / no Chromium). Always use `planner-dev-vrt` or the `lookbook-vrt` service.
