#!/bin/sh
# REST API 0.1 examples. Replace the placeholders, then run:
#   chmod +x example.sh && ./example.sh
#
# See ../../getting-started.md for conventions and workflows.

set -eu

API_KEY='!!!your_secret_api_key!!!'
URL='http://localhost:3000'
AUTH="Api-Key: ${API_KEY}"
JSON='Content-Type: application/json'

# EXAMPLE 1 — list destinations
curl -sS -H "$AUTH" "${URL}/api/0.1/destinations.json"

# EXAMPLE 2 — create one destination with a nested visit (geocoded if lat/lng are omitted)
curl -sS -X POST -H "$AUTH" -H "$JSON" "${URL}/api/0.1/destinations.json" -d '{
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

# EXAMPLE 3 — bulk upsert and create a planning when visits have a route ref
curl -sS -X PUT -H "$AUTH" -H "$JSON" "${URL}/api/0.1/destinations.json" -d '{
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

# EXAMPLE 4 — create a planning (routes and stops are materialized automatically)
curl -sS -X POST -H "$AUTH" -H "$JSON" "${URL}/api/0.1/plannings.json" -d '{
  "name": "Monday",
  "ref": "PLAN-MON",
  "date": "2026-09-14"
}'

# EXAMPLE 5 — start global optimization, then poll the job until it disappears or failed_at is set
# JOB=$(curl -sS -H "$AUTH" "${URL}/api/0.1/plannings/ref:PLAN-MON/optimize.json?global=true" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
# curl -sS -H "$AUTH" "${URL}/api/0.1/jobs/${JOB}.json"

# EXAMPLE 6 — move stop 10 to index 3 on route 2 of planning 1 (-1 appends at the end)
# curl -sS -X PATCH -H "$AUTH" "${URL}/api/0.1/plannings/1/routes/2/stops/10/move/3.json"
