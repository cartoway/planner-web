// Copyright © Cartoway
// Keep in sync with _routeHiddenOnMap / filterVisibleRouteIds in
// app/assets/javascripts/routes_layers.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

// Mirrors RoutesLayer._routeHiddenOnMap (DOM first, then routes[].hidden).
function routeHiddenOnMap(routeId, routes, documentLike) {
  if (documentLike) {
    var toggleIcon = documentLike.querySelector(
      '.route[data-route-id="' + routeId + '"] .toggle i'
    )
    if (toggleIcon) {
      return toggleIcon.classList.contains('fa-eye-slash')
    }
  }
  var list = routes || []
  for (var i = 0; i < list.length; i++) {
    if (String(list[i].route_id) === String(routeId) && list[i].hidden) {
      return true
    }
  }
  return false
}

function filterVisibleRouteIds(routeIds, routes, documentLike) {
  return (routeIds || []).filter(function(routeId) {
    return !routeHiddenOnMap(routeId, routes, documentLike)
  })
}

function makeDoc(routeId, eyeSlash) {
  var icon = {
    classList: {
      contains: function(name) {
        return eyeSlash ? name === 'fa-eye-slash' : name === 'fa-eye'
      }
    }
  }
  return {
    querySelector: function(sel) {
      if (sel.indexOf('data-route-id="' + routeId + '"') !== -1) return icon
      return null
    }
  }
}

describe('routes_layers hidden visibility after planning actions', () => {
  it('keeps eye-hidden routes out of map selection even when still checked', () => {
    var routes = [
      { route_id: 1, hidden: false },
      { route_id: 2, hidden: true },
      { route_id: 3, hidden: false, locked: true }
    ]
    // Checklist still has all three checked (eye-hide does not uncheck).
    var selected = [1, 2, 3]
    assert.deepEqual(
      filterVisibleRouteIds(selected, routes, null),
      [1, 3]
    )
  })

  it('prefers sidebar eye icon over stale routes[].hidden', () => {
    var routes = [{ route_id: 5, hidden: true }]
    // User just clicked eye to show — memory not synced yet, DOM already fa-eye.
    assert.equal(routeHiddenOnMap(5, routes, makeDoc(5, false)), false)
    // User just hid — memory still hidden:false, DOM already fa-eye-slash.
    assert.equal(
      routeHiddenOnMap(5, [{ route_id: 5, hidden: false }], makeDoc(5, true)),
      true
    )
  })
})
