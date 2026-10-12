// Copyright © Cartoway
// Keep in sync with hasInactiveStopsOnVehicleRoutes in app/assets/javascripts/plannings.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

function hasInactiveStops(counters) {
  return counters.some(function(c) {
    var size = parseInt(c.size, 10)
    var active = parseInt(c.active, 10)
    return !isNaN(size) && !isNaN(active) && active !== size
  })
}

describe('optimization active_only visibility', () => {
  it('hides when all vehicle-route stops are active', () => {
    assert.equal(hasInactiveStops([
      { size: '5', active: '5' },
      { size: '2', active: '2' }
    ]), false)
  })

  it('shows when a vehicle route has inactive stops', () => {
    assert.equal(hasInactiveStops([
      { size: '5', active: '4' },
      { size: '2', active: '2' }
    ]), true)
  })

  it('ignores out-of-route counters that only expose size-active', () => {
    // Out-of-route route-info has data-size-active=size and no data-size — must not count.
    assert.equal(hasInactiveStops([
      { size: '5', active: '5' }
      // out-of-route omitted from counters by vehicleRouteStopCounters()
    ]), false)
  })

  it('hides when counters are missing (no manage_route_stops UI)', () => {
    assert.equal(hasInactiveStops([]), false)
  })
})
