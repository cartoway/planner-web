# REST API 0.1 — Getting started

Machine-readable reference: `GET /api/0.1/swagger_doc` (Swagger 2.0).
Simplified domain model: [Model-simpel.svg](./Model-simpel.svg).

This guide covers conventions, typical workflows, and the core resources used to integrate a third-party system. It does not cover the iframe Web API (`/api-web`) or telematics device endpoints.

## Versions

| Version | Base path | Role |
|---------|-----------|------|
| **0.1** | `/api/0.1` | Stable REST API. Use this for integrations. |
| **100** | `/api/100` | Small additive surface (relations, optimized insertion, store reloads). Combine with 0.1; it does not replace it. |

Replace `{base}` below with your planner host, for example `https://planner.cartoway.com`.

## Authentication

Every request is scoped to the `Customer` of the authenticated `User`.

Send the user API key **either** as a query parameter **or** as a header (not both required):

```
GET {base}/api/0.1/destinations.json?api_key=YOUR_API_KEY
```

```
curl -H "Api-Key: YOUR_API_KEY" "{base}/api/0.1/destinations.json"
```

- Admin keys unlock extra operations on `Customer`, `User`, `Vehicle` (depending on config) and `Profile`.
- HTTP **402** means the customer subscription has expired.
- HTTP **403** means the user is authenticated but not allowed to perform the action (CanCan).

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

There is **no pagination**. Lists return the whole customer scope. Narrow payloads with `ids`, `begin_date` / `end_date`, `tags`, or `active`.

## Times and locales

- Input schedule fields (`duration`, `time_window_start_1`, vehicle open/close, …): `HH:MM` or `HH:MM:SS`.
- Output times are DateTime (ISO-like), often computed from the planning date.
- `Accept-Language` translates functional messages and selects CSV column headers (`en` vs `fr`). HTTP status codes are not translated.
- Date filters follow the locale (`en`: `mm-dd-yyyy`, `fr`: `dd-mm-yyyy`).

## Errors

JSON error body:

```json
{ "message": "Unauthorized.", "status": 401 }
```

| Status | Meaning |
|--------|---------|
| 400 | Bad request / invalid index / loop |
| 401 | Missing or invalid API key |
| 402 | Subscription expired |
| 403 | Authenticated but forbidden |
| 404 | Resource not found |
| 409 | Conflict (optimizer already running, job in transmission) |
| 422 | Validation error |
| 500 | Server error |

## Geocoding

If `lat` / `lng` are omitted on create or update, the address is geocoded automatically. To force a new geocode after an address change, send the new address with empty `lat` and `lng`.

`PATCH /destinations/geocode` and `PATCH /destinations/reverse` compute a result **without saving**. Persist with a subsequent update.

## Asynchronous jobs

Heavy operations (planning/route optimization, bulk geocoding) return a `Job` and run in the background.

1. Call the operation (for example `GET /plannings/:id/optimize`).
2. HTTP **200** with a `Job` object means work started. HTTP **409** means another optimizer job is already running.
3. Poll `GET /jobs/:id` until the job disappears (success) or `failed_at` is set.
4. Cancel with `DELETE /jobs/:id` (HTTP **409** if the job is already in transmission).

A customer has at most one optimizer job, one destination-geocoding job and one store-geocoding job at a time.

---

## Workflows

Replace `YOUR_API_KEY` and ids. Header auth is used throughout.

### 1. Create or import destinations and visits

Create one destination with a nested visit:

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

Bulk upsert (JSON). Same `ref` updates the existing destination. If every visit has a `route` (or `ref_vehicle`) **or** you send a `planning` object, a planning is created in the same call:

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

CSV upload uses `multipart/form-data` and localized headers (`Accept-Language`). See `importDestinations` in Swagger.

### 2. Create a planning

There is **no** “create route” or “create stop” endpoint. `POST /plannings` creates:

- one unassigned (out-of-route) route
- one route per vehicle of the chosen `vehicle_usage_set`
- one stop per matching visit (filtered by `tag_ids` / `tag_operation` when set)

```sh
curl -X POST -H "Api-Key: YOUR_API_KEY" -H "Content-Type: application/json" \
  "{base}/api/0.1/plannings.json" \
  -d '{"name": "Monday", "ref": "PLAN-MON", "date": "2026-09-14"}'
```

### 3. Optimize then poll the job

```sh
# Start (global=true allows moving visits between routes)
curl -H "Api-Key: YOUR_API_KEY" \
  "{base}/api/0.1/plannings/ref:PLAN-MON/optimize.json?global=true"

# Poll until the job is gone or failed_at is set
curl -H "Api-Key: YOUR_API_KEY" "{base}/api/0.1/jobs/{job_id}.json"
```

Then fetch the planning again (`GET /plannings/:id`) to read updated routes and stops.

### 4. Move stops / automatic insert

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

### 5. Zoning then apply

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
| **Jobs** | Async optimizer / geocoding. | `GET /jobs`, `GET/DELETE /jobs/:id` |
| **Geocoder** | Address search (not persisted). | `GET /geocoder/search?q=` |

## Code samples

- [cURL](./examples/curl/example.sh)
- [Python](./examples/python/example.py)
- [Ruby](./examples/ruby/example.rb)
- [PHP](./examples/php/example.php)
