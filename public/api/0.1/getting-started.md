# REST API 0.1 — Getting started

Machine-readable reference: `GET /api/0.1/openapi.json?scope=happy_path` (OpenAPI 3.0 for the numbered flow below). `scope=core` is the rest of the integration surface (no admin/devices). Omit `scope` for the full catalog (`happy_path` / `core` / `admin` / `devices`). Swagger 2.0 remains at `GET /api/0.1/swagger_doc` (grape-swagger source of truth).
Simplified domain model: [Model-simpel.svg](./Model-simpel.svg).

This guide covers conventions, a copy-paste happy path, then guided **optimizer**, **zoning**, and **field execution** (Cartoway Deliver) flows, pitfalls, and the core resources used to integrate a third-party system. Other telematics connectors are out of scope. Iframe views (`/api-web`) are covered only for authentication.

## Versions

| Version | Base path | Role |
|---------|-----------|------|
| **0.1** | `/api/0.1` | Stable full REST surface. Poll `GET /jobs/:id` until `status` is `succeeded` or `failed`. `GET /destinations` without `page` is a bare array; with `page` it returns `{ items, page, per_page, total }`. Use this for integrations. |
| **100** | `/api/100` | Extra endpoints whose contracts would be breaking on 0.1 (relations, candidate insert, planning insert, …). |

Replace `{base}` below with your planner host, for example `https://planner.cartoway.com`.

## Authentication

Every request is scoped to the `Customer` of the authenticated `User`.

The `api_key` is on the **user** form in the web UI (read-only key field). Each user has their own key.

Send it **either** as a query parameter **or** as a header (not both required):

```
GET {base}/api/0.1/destinations.json?api_key=YOUR_API_KEY
```

```
curl -H "Api-Key: YOUR_API_KEY" "{base}/api/0.1/destinations.json"
```

- Admin keys unlock extra operations on `Customer`, `User`, `Vehicle` (depending on config) and `Profile`.
- HTTP **402** means the customer subscription has expired.
- HTTP **403** means the user is authenticated but not allowed to perform the action (CanCan).

## Web embeds (`/api-web/0.1`)

HTML views (planning, destinations map, zoning, print) for an iframe or an LLM fetch. Same `api_key` as REST, plus a short-lived embed token so the user key does not sit in the iframe URL.

| Mode | How |
|------|-----|
| Query `api_key` | `GET /api-web/0.1/plannings/7/edit?api_key=YOUR_API_KEY` (existing) |
| Header `Api-Key` | same as REST |
| Embed token | `POST /api/0.1/embed_tokens` then `?embed_token=…`, header `Embed-Token`, or `Authorization: Bearer …` |

```sh
curl -X POST -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/embed_tokens.json" \
  -d '{"expires_in": 3600, "origin": "https://erp.example.com"}'
```

`origin` (optional) sets `Content-Security-Policy: frame-ancestors` on the view. Token lifetime is 60–86400 seconds (default 3600). For ChatGPT / Claude, mint a token with the API key then fetch the view with `Authorization: Bearer`.

---

## Account setup

Do this once per customer before the first daily import. A new account already has a default store, one deliverable unit, vehicles and a vehicle usage set — fetch those ids in the happy path. Add anything extra you need:

| What | Why | How |
|------|-----|-----|
| Vehicles with a stable `ref` | Import assigns visits via `visit.route` / `visit.ref_vehicle`, which must match `vehicle.ref` | Admin creates vehicles. List: `GET /vehicles.json`. Set ref: `PUT /vehicles/:id.json` or `PUT /vehicles/ref:VEH-A.json`. Bulk fleet + hours: `PUT /vehicle_usage_sets.json` with `replace_vehicles: true` |
| Extra deliverable units | Visit quantities and vehicle capacities refer to these | `POST /deliverable_units` `{ "label": "kg", "ref": "kg" }` |
| Cartoway Deliver (admin) | Send routes to the driver app; statuses and GPS come back | Reserved to Cartoway / reseller |
| Custom attributes on `stop_visit` | Driver-editable fields on the phone (comment, anomaly list, …) | `POST /custom_attributes.json` — see [Field execution](#field-execution) |
| A stable `planning.ref` per operational day | Upsert the day's plan without duplicates | Sent on import (`planning.ref`) or `POST /plannings` |

`planning.date` is the **operational** day of the routes, not an order date. Store an order date in a visit custom attribute or in `destination.comment` if you need it; the solver does not route on it.

---

## Happy path

Replace `YOUR_API_KEY`. A customer already has a default store, deliverable unit, vehicles and a vehicle usage set — fetch those ids before creating visits.

There is **no** create-route or create-stop endpoint. Creating a planning materializes them.

### 1. Read units and vehicles

```sh
curl -H "Api-Key: YOUR_API_KEY" "{base}/api/0.1/deliverable_units.json"
curl -H "Api-Key: YOUR_API_KEY" "{base}/api/0.1/vehicles.json"
```

Typical excerpts (fields omitted):

```json
[{ "id": 1, "label": "Pallet", "ref": "PAL" }]
```

```json
[{ "id": 2, "ref": "VEH-1", "name": "Truck 1", "capacities": [{ "deliverable_unit_id": 1, "quantity": 48 }] }]
```

Use `deliverable_unit_id` in visit `quantities`. Use vehicle `ref` as `visit.route` on import (it is **not** a route id).

### 2. Create a destination with a nested visit

```sh
curl -X POST -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/destinations.json" \
  -d '{
    "ref": "CLIENT-12",
    "name": "Acme",
    "street": "12 avenue Thiers",
    "postalcode": "33100",
    "city": "Bordeaux",
    "country": "France",
    "visits": [{
      "ref": "V1",
      "duration": "00:10:00",
      "time_window_start_1": "08:00",
      "time_window_end_1": "12:00",
      "quantities": [{"deliverable_unit_id": 1, "delivery": 1.0}]
    }]
  }'
```

Response excerpt:

```json
{
  "id": 42,
  "ref": "CLIENT-12",
  "lat": 44.8378,
  "lng": -0.5792,
  "visits": [{ "id": 11, "ref": "V1", "duration": "00:10:00" }]
}
```

Same `ref` on a later `PUT /destinations` **updates** the destination (upsert). Address is geocoded when `lat` / `lng` are omitted.

### 3. Create a planning

```sh
curl -X POST -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/plannings.json" \
  -d '{"name": "Monday", "ref": "PLAN-MON", "date": "2026-09-14"}'
```

Response excerpt — `GET /plannings/:id` returns metadata and `route_ids`, **not** nested stops:

```json
{ "id": 7, "ref": "PLAN-MON", "date": "2026-09-14", "route_ids": [20, 21], "outdated": true }
```

This created one unassigned route plus one route per vehicle of the default `vehicle_usage_set`, and one stop per matching visit.

### 4. Optimize, then poll the job

```sh
curl -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/ref:PLAN-MON/optimize.json?global=true"
```

`global=true` allows moving visits between routes. HTTP **200** with a job:

```json
{ "id": 88, "type": "optimizer", "status": "running", "failed_at": null, "progress": {} }
```

Poll until **success or failure**:

```sh
curl -H "Api-Key: YOUR_API_KEY" "{base}/api/0.1/jobs/88.json"
```

| Poll result | Meaning |
|-------------|---------|
| HTTP **200**, `status: "running"` | Still running. Wait and poll again. |
| HTTP **200**, `status: "failed"` (`failed_at` set) | Failed. Read `progress` / message; do not treat as success. |
| HTTP **200**, `status: "succeeded"` | **Success.** The Delayed::Job row is gone; the last result is remembered. |
| HTTP **200**, `status: "killed"` | Cancelled (DELETE /jobs/:id or UI cancel). Remembered like success/failure. |
| HTTP **404** (`{"message":"Job not found.","status":404}`) | This id was never a job of this customer. |
| HTTP **409** | Another optimizer job is already running. |
| HTTP **304** on optimize | Solver found no solution. |

Then reload routes (not only the planning):

```sh
curl -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/ref:PLAN-MON/routes.json"
```

Response excerpt:

```json
[{
  "id": 21,
  "vehicle_usage_id": 3,
  "vehicle_ref": "VEH-1",
  "outdated": false,
  "stops": [{
    "id": 55,
    "index": 1,
    "stop_type": "visit",
    "visit_id": 11,
    "time": "2026-09-14T08:12:00",
    "out_of_window": false,
    "active": true
  }]
}]
```

The unassigned route has `vehicle_usage_id: null`. Check stop flags (`out_of_window`, `out_of_capacity`, …) after optimize.

`global=true` lets the solver move visits between unlocked routes. To keep the current vehicle assignment and only reorder, omit `global` or pass `global=false`. Per-route optimize, locks, and cancel: [Optimizer](#optimizer). Sector assignment before optimize: [Zoning](#zoning). Send to Cartoway Deliver and poll driver statuses: [Field execution](#field-execution).

Runnable samples: [cURL](./examples/curl/example.sh), [Python](./examples/python/example.py), [Ruby](./examples/ruby/example.rb), [PHP](./examples/php/example.php), [Postman / Insomnia](./examples/postman/Planner-API-0.1.collection.json).

---

## Pitfalls

- **Job `status: succeeded` means success.** Poll until that, `failed`, or `killed`. HTTP **404** means this id was never a job of this customer — do not treat 404 as success.
- **No create-stop / create-route.** `POST /plannings` (or import with `planning` / `visit.route`) materializes them. Then move, lock, or activate stops.
- **`GET /plannings/:id` has no stops.** Use `GET /plannings/:id/routes.json`.
- **`visit.route` on import is a vehicle `ref` (or route index/name), not a route id.** Prefer `ref_vehicle` if you want to be explicit.
- **Bulk `DELETE` with omitted or empty `ids` deletes all** destinations or visits of the customer. Always pass `ids`.
- **Error bodies are `{ "message": "…", "status": 401 }`.** Import validation (HTTP 422) adds `errors` (array of details) and repeats them joined in `message`.
- **Date filters follow `Accept-Language`**, not ISO: `en` is `mm-dd-yyyy`, `fr` is `dd-mm-yyyy`. CSV headers follow the same header.
- **`automatic_insert` is distance-only** (ignores time windows). Fine for a few stops; use zoning then optimize for batches.
- **Zoning assigns vehicles, optimize sequences stops.** `apply_zonings` uses zonings already linked on the planning (`zoning_ids` on create/update). It does **not** take `?zoning_ids=`. Then call optimize with `global=false`.
- **`PATCH /zonings/:id/automatic/:planning_id` clears existing zones** in that zoning. `n` must be ≤ fleet size.
- **Pagination is opt-in.** Without `page`, lists return the whole customer scope. `GET /destinations?page=1` wraps `{ items, page, per_page, total }` (`per_page` default 100, max 500). Filter with `ids`, dates, tags, or `active`.
- **Deprecated field names still appear in some payloads:** `open`/`close` → `time_window_*`; `quantity` → `pickup`/`delivery`; `out_of_date` → `outdated`; `capacity` → `capacities`.
- **`street` is one field** (`"12 rue de la Paix"`). There is no separate house-number column. Put building / floor / intercom in `detail` — stuffing that into `street` breaks geocoding.
- **`destination.comment` is a note to the driver**, not the driver's feedback. Driver-entered text lives on a `stop_visit` custom attribute (see [Field execution](#field-execution)).
- **No weekly calendar.** A visit has at most two windows for **that** day (`time_window_*_1` and `time_window_*_2`). If the source system has “Mon–Fri 8–12 / 14–18”, extract the slots for the delivery day before import.
- **Visit upsert key is `destination.ref` + `visit.ref`.** Same destination can have several visits (several orders, several days). Omit `visit.ref` only when a destination never has more than one visit.
- **`DELETE …/by_tags` keeps objects that miss any of the tags.** The destination or visit must have **all** provided tags. Empty result is HTTP **304**.
- **Without `send_multiple`, the driver never receives the route** and no status comes back. `POST /devices/deliver/send_multiple` requires a numeric `planning_id` (not `ref:…`).
- **No REST 0.1 webhook for stop status.** Poll `GET /plannings/:id/routes.json`. `?with_geojson=true` is the **planned** geometry, not the truck's real trace. `GET /vehicles/current_position.json` is a live snapshot; REST 0.1 does not keep GPS history.

---

## Identifiers

Most path and filter parameters accept:

- a numeric id: `42`
- an external reference: `ref:CLIENT-12`

References must not contain commas. Bulk filters:

```
?ids=42,43,ref:CLIENT-12
```

`ref` is the upsert key on destination/visit/store imports: the same `ref` updates the existing object instead of creating a duplicate.

## Formats

Pick the format with the URL extension (default: JSON):

| Extension | Content-Type | Typical resources |
|-----------|--------------|-------------------|
| `.json` | `application/json; charset=UTF-8` | all |
| `.xml` | `application/xml` | all |
| `.geojson` | `application/vnd.geo+json` | destinations, visits, plannings, routes |
| `.ics` | `text/calendar` | plannings, routes |

Request bodies: `application/json; charset=UTF-8` or `application/xml`. CSV imports use `multipart/form-data`.

## Times and locales

- Input schedule fields (`duration`, `time_window_start_1`, vehicle open/close, …): `HH:MM` or `HH:MM:SS`.
- Output times are DateTime (ISO-like), often computed from the planning date.
- `Accept-Language` translates functional messages and selects CSV column headers (`en` vs `fr`). HTTP status codes are not translated.

## Errors

Typical auth/status body:

```json
{ "message": "Unauthorized.", "status": 401 }
```

Import validation (HTTP 422):

```json
{ "message": "\"name\" missing.", "status": 422, "errors": ["\"name\" missing."] }
```

| Status | Meaning |
|--------|---------|
| 304 | Not modified / optimizer found no solution |
| 400 | Bad request / invalid index / loop |
| 401 | Missing or invalid API key |
| 402 | Subscription expired |
| 403 | Authenticated but forbidden |
| 404 | Resource not found (including `GET /jobs/:id` when this id was never a job of this customer) |
| 409 | Conflict (optimizer already running, job in transmission) |
| 422 | Validation error |
| 500 | Server error |

## Geocoding

If `lat` / `lng` are omitted on create or update, the address is geocoded automatically. To force a new geocode after an address change, send the new address with empty `lat` and `lng`.

`PATCH /destinations/geocode` and `PATCH /destinations/reverse` compute a result **without saving**. Persist with a subsequent update.

Heavy geocoding during import may return HTTP **202** and a job; poll like optimize.

## Asynchronous jobs

A customer has at most one optimizer job, one destination-geocoding job and one store-geocoding job at a time.

1. Call the operation (for example `GET /plannings/:id/optimize`).
2. HTTP **200** with a `Job` object means work started.
3. Poll `GET /jobs/:id` until `status` is `succeeded` or `failed`.
4. Cancel with `DELETE /jobs/:id` (HTTP **409** if the job is already in transmission).

---

## More workflows

### Import JSON (upsert + optional planning)

If every visit has a `route` (or `ref_vehicle`) **or** you send a `planning` object, a planning is created in the same call.

JSON quantities use `deliverable_unit_id` (from `GET /deliverable_units`) or `deliverable_unit_label` (the unit's **label**, e.g. `"Pallet"`). There is no `deliverable_unit_ref` lookup — the unit `ref` (`PAL`) is unused here. CSV columns are `delivery[label]` / `livraison[label]`, still the label between brackets.

A new planning created by import receives the **intersection** of destination/visit tags across the imported rows. Tag visits with the operational day if you want the plan to include only that day's work (`tag_operation` `and` / `or` on the planning). Planning tags then keep only compatible visits on the plan.

```sh
curl -X PUT -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/destinations.json" \
  -d '{
    "planning": {"name": "Monday", "ref": "PLAN-MON", "date": "2026-09-14"},
    "destinations": [{
      "ref": "CLIENT-12",
      "name": "Acme",
      "street": "12 avenue Thiers",
      "detail": "Building B, 2nd floor",
      "postalcode": "33100",
      "city": "Bordeaux",
      "country": "France",
      "phone_number": "+33556123456",
      "comment": "Ring at the back, ask for invoice.",
      "visits": [{
        "ref": "ORDER-88901",
        "duration": "00:10:00",
        "time_window_start_1": "08:00",
        "time_window_end_1": "12:00",
        "time_window_start_2": "14:00",
        "time_window_end_2": "18:00",
        "route": "VEH-1",
        "active": true,
        "quantities": [{"deliverable_unit_label": "Pallet", "delivery": 1.0}],
        "tags": ["2026-09-14"]
      }]
    }]
  }'
```

To drop a day's destinations or visits after the fact, pass tag **ids** (or the tag's `ref:` — that is the `ref` field, not the label). Import `tags: ["monday"]` creates/finds by **label**; `GET /tags.json` to resolve ids:

```sh
curl -X DELETE -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/destinations/by_tags.json?tag_ids=3"
curl -X DELETE -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/visits/by_tags.json?tag_ids=3"
```

### Import CSV

`PUT /destinations` with `multipart/form-data` field `file`. Headers must match `Accept-Language`. See `importDestinations` in Swagger for the full column list.

English (`Accept-Language: en`). `vehicle` is the vehicle ref; `reference plan` upserts a planning by `ref`. Date follows `Accept-Language` (`mm-dd-yyyy` in `en`). Bracket the unit **label** on quantity columns:

```
reference,name,street,detail,postalcode,city,country,phone,comment,visit duration,open 1,close 1,open 2,close 2,delivery[Pallet],vehicle,reference plan,date
CLIENT-12,Acme,12 avenue Thiers,Building B,33100,Bordeaux,France,+33556123456,Ring at the back,00:10:00,08:00,12:00,14:00,18:00,1,VEH-1,PLAN-MON,09-14-2026
```

```sh
curl -X PUT -H "Api-Key: YOUR_API_KEY" -H "Accept-Language: en" \
  "{base}/api/0.1/destinations.json" \
  -F "file=@destinations.csv"
```

French (`Accept-Language: fr`, dates `dd/mm/yyyy`):

```
référence,nom,voie,complément,code postal,ville,pays,téléphone,commentaire,durée visite,horaire début 1,horaire fin 1,horaire début 2,horaire fin 2,livraison[Pallet],véhicule,référence plan,date
CLIENT-12,Acme,12 avenue Thiers,Bâtiment B,33100,Bordeaux,France,+33556123456,Sonner à l'arrière,00:10:00,08:00,12:00,14:00,18:00,1,VEH-1,PLAN-MON,14/09/2026
```

```sh
curl -X PUT -H "Api-Key: YOUR_API_KEY" -H "Accept-Language: fr" \
  "{base}/api/0.1/destinations.json" \
  -F "file=@destinations.csv"
```

### Move stops / automatic insert

Move one stop to another index (same route or another). Index `-1` appends at the end:

```sh
curl -X PATCH -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/1/routes/2/stops/10/move/3.json"
```

Move visits onto a route; `automatic_insert=true` picks the cheapest index (distance only, no time windows):

```sh
curl -X PATCH -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/1/routes/2/visits/moves.json?visit_ids=11,12&automatic_insert=true"
```

Heuristic insert of existing stops (not for large batches; use [zoning](#zoning) then optimize):

```sh
curl -X PATCH -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/1/automatic_insert.json?stop_ids=10,11"
```

### Field execution (Cartoway Deliver)

Prerequisites: Cartoway Deliver enabled on the account, plus customer options `enable_stop_status` and `enable_vehicle_position`.

1. Import (or create) the planning so stops sit on vehicle routes.
2. Optional: [optimize](#optimizer).
3. Send to the phones — **numeric** planning id (resolve `ref:PLAN-MON` first):

```sh
curl -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/ref:PLAN-MON.json"
# read "id", then:
curl -X POST -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/devices/deliver/send_multiple.json" \
  -d '{"planning_id": 7}'
```

Without step 3 the driver does not receive the route, so **no status comes back**. There is no REST 0.1 webhook for stop status: poll (about every 60 s is enough):

```sh
curl -H "Api-Key: YOUR_API_KEY" -H "Accept-Language: en" \
  "{base}/api/0.1/plannings/ref:PLAN-MON/routes.json"
```

For other telematics connectors, pull remote statuses first with `PATCH /plannings/:id/update_stops_status`. On Deliver the mobile app already writes into the planning; `GET …/routes` is enough.

On each visit stop (`stops[]`):

| Field | Role |
|-------|------|
| `status` | Localized label (`Accept-Language`) |
| `status_code` | Raw code — store this, not the label |
| `status_updated_at` | When the driver validated the status |
| `destination_ref` / `visit_ref` | Join back to the ERP order |
| `custom_attributes.*` | Driver-editable fields defined on the account |

Deliver `status_code` values:

| `status_code` | Typical meaning |
|---------------|-----------------|
| `intransit` | In transit / en route |
| `delivered` | Delivered / completed |
| `exception` | Exception / anomaly |
| `undelivered` | Undelivered |

**Custom attributes.** `object_class: visit` (and `vehicle` / `route`) can be shown read-only on the phone when `mobile_visible` is true. Fields the driver **edits** must be `object_class: stop_visit`. `object_type: array` is a dropdown; `default_value` is the list of choices, the stored value is one of those strings.

```sh
curl -X POST -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/custom_attributes.json" \
  -d '{"name": "driver_comment", "object_type": "string", "object_class": "stop_visit"}'

curl -X POST -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/custom_attributes.json" \
  -d '{"name": "anomaly", "object_type": "array", "object_class": "stop_visit", "default_value": ["Broken", "Refused", "Absent"]}'
```

Read them back on `stops[].custom_attributes.driver_comment` / `.anomaly`. Store **status_code + list value + free text**, not a boolean.

**Live GPS snapshot** (requires `enable_vehicle_position`):

```sh
curl -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/vehicles/current_position.json?ids=2"
```

Response items: `vehicle_id`, `lat`, `lng`, `direction`, `speed`, `time`, `device_name`. Pass `ids` (vehicle ids). REST 0.1 does not keep GPS history. `GET /plannings/:id.json?with_geojson=true` is the **planned** track, not the real one.

---

## Optimizer

Zoning (and import `visit.route`) put visits on vehicles. Optimize **orders** them, and with `global=true` may **reassign** them. One optimizer job per customer. Poll as in the [happy path](#4-optimize-then-poll-the-job). Then `GET /plannings/:id/routes.json`.

| Goal | Call |
|------|------|
| Reassign between unlocked routes | `GET /plannings/:id/optimize.json?global=true` |
| Keep current vehicles, only sequence | `GET /plannings/:id/optimize.json` (`global` defaults to `false`) |
| One route only (visits stay on it) | `PATCH /plannings/:id/routes/:route_id/optimize.json` |

```sh
# After zoning or import with visit.route: do not pass global=true
curl -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/ref:PLAN-MON/optimize.json"

# Single unlocked route
curl -X PATCH -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/ref:PLAN-MON/routes/21/optimize.json"
```

- Locked routes are skipped. Lock via `PUT /plannings/:id` with `routes: [{ "id": 21, "locked": true }]`.
- `active_only=true` (default): inactive stops are ignored and stay inactive.
- HTTP **409** if another optimizer job is running. HTTP **304** if the solver finds no solution.
- Cancel with `DELETE /jobs/:id` once the job is transmitted (`progress.job_id` set). HTTP **409** during transmission.
- Do not use `synchronous` (deprecated). Writes while an optimizer is running are rejected.

---

## Zoning

A zoning is a named set of **zones** (polygons), each optionally linked to a `vehicle_id`. Applying it **assigns** unlocked stops to those vehicles. It does **not** order stops — call optimize with `global=false` afterwards.

`GET /plannings/:id/apply_zonings` uses zonings already on the planning. It does **not** accept `zoning_ids` as a query parameter.

### 1. Create an empty zoning

```sh
curl -X POST -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/zonings.json" -d '{"name": "City sectors"}'
```

```json
{ "id": 5, "name": "City sectors", "zones": [] }
```

### 2. Fill zones (pick one)

**Automatic clustering** (usual integration path). Includes unassigned stops. **Clears previous zones.** Each new zone is linked to a vehicle. `n` defaults to the fleet size and must not exceed it.

```sh
curl -X PATCH -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/zonings/5/automatic/7.json"
```

`7` is the **planning id**. Optional `?n=3`.

**From existing routes** — only stops already on a vehicle route (not the unassigned route):

```sh
curl -X PATCH -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/zonings/5/from_planning/7.json"
```

**Isochrone / isodistance** — coverage from each vehicle start store (`size` in seconds or metres). Also clears previous zones. Not a clustering of visits.

Or `PUT /zonings/:id` with `zones: [{ "name": "North", "vehicle_id": 2, "polygon": { … GeoJSON… } }]`.

### 3. Link the zoning on the planning, then apply

```sh
curl -X PUT -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/plannings/ref:PLAN-MON.json" \
  -d '{"zoning_ids": [5]}'

curl -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/ref:PLAN-MON/apply_zonings.json"
```

HTTP **204**. Pass `?details=true` to get the planning body. You can also set `zoning_ids` on `POST /plannings`.

Locked routes are not reassigned. Stops outside every zone go to the unassigned route (`vehicle_usage_id: null`).

### 4. Sequence each route

```sh
curl -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/ref:PLAN-MON/optimize.json"

curl -H "Api-Key: YOUR_API_KEY" "{base}/api/0.1/jobs/88.json"

curl -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/ref:PLAN-MON/routes.json"
```

Do not pass `global=true` here unless you want the solver to undo the sectors.

---

## Resource catalogue

| Resource | Role | Key endpoints |
|----------|------|----------------|
| **Destinations** | Geographic points (customers). Nested **visits** hold the work and constraints. | `GET/POST /destinations`, `PUT /destinations` (import), `GET/PUT/DELETE /destinations/:id` |
| **Visits** | Actions at a destination (time windows, quantities, tags, `force_position`). Same destination may have several visits. | nested under `/destinations/:id/visits`, `GET /visits`, bulk `PUT /visits` |
| **Deliverable units** | Quantity units (pallets, kg, …) linking visit pickup/delivery to vehicle capacity. One default unit exists per customer. | `/deliverable_units` |
| **Stores** | Depots (start/stop/reload). One default store exists per customer. | `/stores`, `PUT /stores` (import) |
| **Vehicles** | Physical vehicle (capacity, router, speed, devices). | `/vehicles` |
| **VehicleUsageSet** | Context of use (morning/evening). Holds default times and stores. | `/vehicle_usage_sets` |
| **VehicleUsage** | One vehicle inside one set (overrides set defaults). | `/vehicle_usage_sets/:set_id/vehicle_usages/:id` |
| **Plannings** | A day’s (or period’s) set of routes. Creating one materializes routes and stops. | `/plannings`, `.../optimize`, `.../refresh`, `.../automatic_insert`, `.../apply_zonings` |
| **Routes** | Track of one vehicle in a planning (or the unassigned route when `vehicle_usage_id` is null). | `/plannings/:id/routes`, `.../visits/moves`, `.../optimize` |
| **Stops** | Occurrence of a visit, store reload or rest on a route. Created with the planning; activate, lock, or move them. Field `status` / `status_code` after Deliver (or after `update_stops_status`). | `/plannings/:id/routes/:id/stops/:id` |
| **Tags** | Labels to subset visits when creating a planning (`tag_operation`: `and` / `or`). | `/tags` |
| **Custom attributes** | Extra typed fields on visit, stop_visit, stop_store, vehicle or route. Driver-editable ones use `stop_visit`. | `/custom_attributes` |
| **Zonings / Zones** | Polygons linked to vehicles; apply to a planning to assign stops. | `/zonings`, `.../automatic/:planning_id`, `/plannings/:id/apply_zonings` |
| **Jobs** | Async optimizer / geocoding. Poll until `status` is `succeeded` or `failed`. | `GET /jobs`, `GET/DELETE /jobs/:id` |
| **Geocoder** | Address search (not persisted). | `GET /geocoder/search?q=` |
| **Devices / Deliver** | Send a planning to Cartoway Deliver; live GPS via `GET /vehicles/current_position`. | `POST /devices/deliver/send_multiple`, `GET /vehicles/current_position` |

## Code samples

- [cURL](./examples/curl/example.sh)
- [Python](./examples/python/example.py)
- [Ruby](./examples/ruby/example.rb)
- [PHP](./examples/php/example.php)

### Postman / Insomnia

Curated happy-path collection (not a dump of every Swagger operation):

- [Planner-API-0.1.collection.json](./examples/postman/Planner-API-0.1.collection.json)
- [Planner-API-0.1.environment.json](./examples/postman/Planner-API-0.1.environment.json)
- Sample CSV: [destinations.en.csv](./examples/postman/destinations.en.csv)

**Postman:** Import both JSON files, set `api_key`, run the Happy path folder in order. Optimize saves `job_id`; create planning saves `planning_id`. `base` follows `swagger_docs_base_path` without the trailing slash (default `http://localhost:8080`). Point it at your own host if you publish the API elsewhere.

**Insomnia:** Import → From File → the collection (v2.1). Then set `api_key` (and `base` if it is not the default). Insomnia understands this format; there is no second file to maintain.

Full endpoint catalog: import `GET /api/0.1/openapi.json` (OpenAPI 3.0) in either tool. `GET /api/0.1/swagger_doc` is Swagger 2.0 for compatibility.
