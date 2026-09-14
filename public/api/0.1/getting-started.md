# REST API 0.1 — Getting started

Machine-readable reference: `GET /api/0.1/openapi.json` (OpenAPI 3.0; import this in codegen, Postman or Insomnia). Swagger 2.0 remains at `GET /api/0.1/swagger_doc` (grape-swagger source of truth).
Simplified domain model: [Model-simpel.svg](./Model-simpel.svg).

This guide covers conventions, a copy-paste happy path, pitfalls, and the core resources used to integrate a third-party system. It does not cover the iframe Web API (`/api-web`) or telematics device endpoints.

## Versions

| Version | Base path | Role |
|---------|-----------|------|
| **0.1** | `/api/0.1` | Stable REST API. Use this for integrations. |
| **100** | `/api/100` | Small additive surface (relations, optimized insertion, store reloads). Combine with 0.1; it does not replace it. |

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
{ "id": 88, "type": "optimizer", "failed_at": null, "progress": {} }
```

Poll until **success or failure**:

```sh
curl -H "Api-Key: YOUR_API_KEY" "{base}/api/0.1/jobs/88.json"
```

| Poll result | Meaning |
|-------------|---------|
| HTTP **200**, `failed_at` null | Still running. Wait and poll again. |
| HTTP **200**, `failed_at` set | Failed. Read `progress` / message; do not treat as success. |
| HTTP **404** (`{"error":"Job not found"}`) | **Success.** The job row is deleted when it finishes. |
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

Runnable samples: [cURL](./examples/curl/example.sh), [Python](./examples/python/example.py), [Ruby](./examples/ruby/example.rb), [PHP](./examples/php/example.php), [Postman / Insomnia](./examples/postman/Planner-API-0.1.collection.json).

---

## Pitfalls

- **Job HTTP 404 means success** (the job is deleted). Do not retry optimize on 404. Failure is `failed_at` set on HTTP 200.
- **No create-stop / create-route.** `POST /plannings` (or import with `planning` / `visit.route`) materializes them. Then move, lock, or activate stops.
- **`GET /plannings/:id` has no stops.** Use `GET /plannings/:id/routes.json`.
- **`visit.route` on import is a vehicle `ref` (or route index/name), not a route id.** Prefer `ref_vehicle` if you want to be explicit.
- **Bulk `DELETE` with omitted or empty `ids` deletes all** destinations or visits of the customer. Always pass `ids`.
- **Error bodies are not uniform.** Auth/status helpers return `{ "message": "Unauthorized.", "status": 401 }`. Import validation is `{ "error": ["…"] }` (HTTP 422). Job miss is `{ "error": "Job not found" }` (HTTP 404).
- **Date filters follow `Accept-Language`**, not ISO: `en` is `mm-dd-yyyy`, `fr` is `dd-mm-yyyy`. CSV headers follow the same header.
- **`automatic_insert` is distance-only** (ignores time windows). Fine for a few stops; use zoning or optimize for batches.
- **No pagination.** Lists return the whole customer scope. Filter with `ids`, dates, tags, or `active`.
- **Deprecated field names still appear in some payloads:** `open`/`close` → `time_window_*`; `quantity` → `pickup`/`delivery`; `out_of_date` → `outdated`; `capacity` → `capacities`.

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
{ "error": ["\"name\" missing."] }
```

| Status | Meaning |
|--------|---------|
| 304 | Not modified / optimizer found no solution |
| 400 | Bad request / invalid index / loop |
| 401 | Missing or invalid API key |
| 402 | Subscription expired |
| 403 | Authenticated but forbidden |
| 404 | Resource not found — **except** `GET /jobs/:id` where 404 means the job finished successfully |
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
3. Poll `GET /jobs/:id` until HTTP **404** (success) or `failed_at` is set.
4. Cancel with `DELETE /jobs/:id` (HTTP **409** if the job is already in transmission).

---

## More workflows

### Import JSON (upsert + optional planning)

If every visit has a `route` (or `ref_vehicle`) **or** you send a `planning` object, a planning is created in the same call:

```sh
curl -X PUT -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/destinations.json" \
  -d '{
    "planning": {"name": "Monday", "ref": "PLAN-MON"},
    "destinations": [{
      "ref": "CLIENT-12",
      "name": "Acme",
      "street": "12 avenue Thiers",
      "postalcode": "33100",
      "city": "Bordeaux",
      "country": "France",
      "visits": [{
        "duration": "00:10:00",
        "time_window_start_1": "08:00",
        "time_window_end_1": "12:00",
        "route": "VEH-1",
        "active": true
      }]
    }]
  }'
```

### Import CSV

`PUT /destinations` with `multipart/form-data` field `file`. Headers must match `Accept-Language`. See `importDestinations` in Swagger for the full column list.

English (`Accept-Language: en`). `vehicle` is the vehicle ref; `plan` creates/updates a planning:

```
reference,name,street,postalcode,city,country,visit duration,open 1,close 1,delivery,vehicle,plan
CLIENT-12,Acme,12 avenue Thiers,33100,Bordeaux,France,00:10:00,08:00,12:00,1,VEH-1,Monday
```

```sh
curl -X PUT -H "Api-Key: YOUR_API_KEY" -H "Accept-Language: en" \
  "{base}/api/0.1/destinations.json" \
  -F "file=@destinations.csv"
```

French (`Accept-Language: fr`):

```
référence,nom,voie,code postal,ville,pays,durée visite,horaire début 1,horaire fin 1,livraison,véhicule,plan
CLIENT-12,Acme,12 avenue Thiers,33100,Bordeaux,France,00:10:00,08:00,12:00,1,VEH-1,Lundi
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

Heuristic insert of existing stops (not for large batches; use zoning instead):

```sh
curl -X PATCH -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/1/automatic_insert.json?stop_ids=10,11"
```

### Zoning then apply

```sh
# Empty zoning
curl -X POST -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/zonings.json" -d '{"name": "City sectors"}'

# Cluster visits into N zones (clears previous zones; each zone is linked to a vehicle)
curl -X PATCH -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/zonings/5/automatic/1.json"

# Assign stops of the planning to the zone vehicles
curl -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/1/apply_zonings.json?zoning_ids=5"
```

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
| **Stops** | Occurrence of a visit, store reload or rest on a route. Created with the planning; activate, lock, or move them. | `/plannings/:id/routes/:id/stops/:id` |
| **Tags** | Labels to subset visits when creating a planning (`tag_operation`: `and` / `or`). | `/tags` |
| **Zonings / Zones** | Polygons linked to vehicles; apply to a planning to assign stops. | `/zonings`, `.../automatic/:planning_id`, `/plannings/:id/apply_zonings` |
| **Jobs** | Async optimizer / geocoding. Poll until HTTP 404 (success) or `failed_at`. | `GET /jobs`, `GET/DELETE /jobs/:id` |
| **Geocoder** | Address search (not persisted). | `GET /geocoder/search?q=` |

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
