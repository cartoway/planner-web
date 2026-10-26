// Copyright © Cartoway
// Keep in sync with pending route-load ownership in app/assets/javascripts/routes_layers.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

function makeXhr(routeIds, readyState) {
  return { _routeIds: routeIds.slice(), readyState: readyState == null ? 1 : readyState, aborted: false, abort: function() { this.aborted = true } }
}

function abortPendingRouteLoads(pending, routeIds) {
  var covered = {}
  ;(routeIds || []).forEach(function(id) { covered[String(id)] = true })
  var seen = []
  ;(routeIds || []).forEach(function(routeId) {
    var prev = pending[String(routeId)]
    if (!prev || prev.readyState === 4 || seen.indexOf(prev) !== -1) return
    seen.push(prev)
    var fullyCovered = (prev._routeIds || []).every(function(id) {
      return covered[String(id)]
    })
    if (fullyCovered) prev.abort()
  })
}

function trackPendingRouteLoads(pending, routeIds, xhr) {
  xhr._routeIds = (routeIds || []).slice()
  ;(routeIds || []).forEach(function(routeId) {
    pending[String(routeId)] = xhr
  })
}

function ownedRouteIds(pending, routeIds, xhr) {
  return (routeIds || []).filter(function(routeId) {
    return pending[String(routeId)] === xhr
  })
}

function filterOwnedFeatures(features, ownedIds) {
  var owned = {}
  ownedIds.forEach(function(id) { owned[String(id)] = true })
  return features.filter(function(feature) {
    var rid = feature.properties && feature.properties.route_id
    return rid && owned[String(rid)]
  })
}

describe('routes_layers pending route loads', () => {
  it('keeps a partially overlapping in-flight load alive and only paints owned routes', () => {
    var pending = {}
    var a = makeXhr([1, 2])
    trackPendingRouteLoads(pending, [1, 2], a)

    abortPendingRouteLoads(pending, [2, 3])
    assert.equal(a.aborted, false)

    var b = makeXhr([2, 3])
    trackPendingRouteLoads(pending, [2, 3], b)

    assert.deepEqual(ownedRouteIds(pending, [1, 2], a), [1])
    assert.deepEqual(ownedRouteIds(pending, [2, 3], b), [2, 3])

    var features = filterOwnedFeatures([
      { properties: { route_id: 1 } },
      { properties: { route_id: 2 } },
      { properties: { store_id: 9 } }
    ], [1])
    assert.deepEqual(features, [{ properties: { route_id: 1 } }])
  })

  it('aborts an in-flight load when the new request covers all its routes', () => {
    var pending = {}
    var a = makeXhr([1, 2])
    trackPendingRouteLoads(pending, [1, 2], a)

    abortPendingRouteLoads(pending, [1, 2, 3])
    assert.equal(a.aborted, true)
  })

  it('treats numeric and string route ids as the same ownership key', () => {
    var pending = {}
    var a = makeXhr([1])
    trackPendingRouteLoads(pending, [1], a)

    assert.equal(pending['1'], a)
    assert.deepEqual(ownedRouteIds(pending, ['1'], a), ['1'])
  })
})
