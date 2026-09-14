#!/usr/bin/env python3
"""REST API 0.1 examples. Replace the placeholders, then run: python3 example.py

See ../../getting-started.md for the happy path, pitfalls, and CSV headers.
"""
import json
import time
import urllib.error
import urllib.parse
import urllib.request

API_KEY = '!!!your_secret_api_key!!!'
URL = 'http://localhost:3000'


def request(method, path, body=None, query=None):
    url = URL + path
    if query:
        url += '?' + urllib.parse.urlencode(query)
    data = None if body is None else json.dumps(body).encode('utf-8')
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={'Api-Key': API_KEY, 'Content-Type': 'application/json', 'Accept': 'application/json'},
    )
    with urllib.request.urlopen(req) as resp:
        raw = resp.read()
        return json.loads(raw) if raw else None


# EXAMPLE 1 — bootstrap: deliverable unit ids and vehicle refs
units = request('GET', '/api/0.1/deliverable_units.json')
print('Deliverable units: %s' % [(u.get('id'), u.get('ref')) for u in units])
vehicles = request('GET', '/api/0.1/vehicles.json')
print('Vehicles: %s' % [(v.get('id'), v.get('ref')) for v in vehicles])

# EXAMPLE 2 — create one destination with a nested visit
created = request('POST', '/api/0.1/destinations.json', {
    'ref': 'CLIENT-12',
    'name': 'Acme',
    'street': '12 avenue Thiers',
    'postalcode': '33100',
    'city': 'Bordeaux',
    'country': 'France',
    'visits': [{
        'ref': 'V1',
        'duration': '00:10:00',
        'time_window_start_1': '08:00',
        'time_window_end_1': '12:00',
        'quantities': [{'deliverable_unit_id': 1, 'delivery': 1.0}],
    }],
})
print('Created destination id=%s' % created['id'])

# EXAMPLE 3 — bulk upsert and create a planning when visits have a vehicle ref
imported = request('PUT', '/api/0.1/destinations.json', {
    'planning': {'name': 'Monday', 'ref': 'PLAN-MON'},
    'destinations': [{
        'ref': 'CLIENT-12',
        'name': 'Acme',
        'street': '12 avenue Thiers',
        'postalcode': '33100',
        'city': 'Bordeaux',
        'country': 'France',
        'visits': [{
            'duration': '00:10:00',
            'time_window_start_1': '08:00',
            'time_window_end_1': '12:00',
            'route': 'VEH-1',
            'active': True,
        }],
    }],
})
print('Imported %s destinations' % len(imported))

# EXAMPLE 4 — create a planning (routes and stops are materialized automatically)
planning = request('POST', '/api/0.1/plannings.json', {
    'name': 'Monday',
    'ref': 'PLAN-MON',
    'date': '2026-09-14',
})
print('Planning id=%s route_ids=%s' % (planning['id'], planning['route_ids']))

# EXAMPLE 5 — start global optimization, then poll until HTTP 404 (success) or failed_at
job = request('GET', '/api/0.1/plannings/%s/optimize.json' % planning['id'], query={'global': 'true'})
if job and job.get('id'):
    print('Optimizer job id=%s' % job['id'])
    while True:
        try:
            status = request('GET', '/api/0.1/jobs/%s.json' % job['id'])
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                print('Job finished')
                break
            raise
        if status.get('failed_at'):
            print('Job failed: %s' % status)
            break
        time.sleep(2)
    routes = request('GET', '/api/0.1/plannings/%s/routes.json' % planning['id'])
    print('Routes after optimize: %s' % [r.get('id') for r in routes])

# EXAMPLE 6 — move a stop (uncomment and set ids)
# request('PATCH', '/api/0.1/plannings/1/routes/2/stops/10/move/3.json')
