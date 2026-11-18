// Copyright © Cartoway
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

// Mirrors customers_index_map_controller customersToFeatures.
function customersToFeatures (customers) {
  return (customers || []).flatMap((customer) => {
    const lat = parseFloat(customer.lat)
    const lng = parseFloat(customer.lng)
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return []
    const status = customer.test ? 'test' : (customer.isActiv ? 'active' : 'inactive')
    const page = Number(customer.page)
    return [{
      type: 'Feature',
      id: customer.id,
      geometry: { type: 'Point', coordinates: [lng, lat] },
      properties: {
        id: customer.id,
        name: customer.name || '',
        vehicles: customer.max_vehicles || 0,
        status,
        page: Number.isFinite(page) && page > 0 ? page : 1
      }
    }]
  })
}


function legendCenterX ({ layoutWidth, insetLeft, insetRight }) {
  const visible = Math.max(0, layoutWidth - insetLeft - insetRight)
  return insetLeft + visible / 2
}

describe('customers index map features', () => {
  it('builds selectable point features with status and list page for positioned customers', () => {
    const features = customersToFeatures([
      { id: 1, name: 'A', lat: '48.8', lng: '2.3', test: false, isActiv: true, max_vehicles: 3, page: 2 },
      { id: 2, name: 'B', lat: null, lng: null, test: true, isActiv: false, page: 9 },
      { id: 3, name: 'C', lat: 45.1, lng: 5.7, test: true, isActiv: true, max_vehicles: 1, page: 3 }
    ])

    assert.equal(features.length, 2)
    assert.deepEqual(features[0].geometry.coordinates, [2.3, 48.8])
    assert.equal(features[0].properties.status, 'active')
    assert.equal(features[0].properties.page, 2)
    assert.equal(features[0].id, 1)
    assert.equal(features[1].properties.status, 'test')
    assert.equal(features[1].properties.page, 3)
  })


  it('centers the legend on the visible map band beside the list', () => {
    assert.equal(legendCenterX({ layoutWidth: 1000, insetLeft: 400, insetRight: 0 }), 700)
    assert.equal(legendCenterX({ layoutWidth: 1000, insetLeft: 0, insetRight: 0 }), 500)
    assert.equal(legendCenterX({ layoutWidth: 1000, insetLeft: 300, insetRight: 200 }), 550)
  })

  it('detects when the list filter q changed for map reload', () => {
    // Mirrors customers_index_map_controller _syncMapFeaturesWithUrlFilter guard.
    const shouldReload = (prevQ, nextQ) => (nextQ || '') !== (prevQ || '')
    assert.equal(shouldReload('', 'acme'), true)
    assert.equal(shouldReload('acme', 'acme'), false)
    assert.equal(shouldReload('acme', ''), true)
  })

  it('marks the selected customer disc in place by element id (operations-style)', async () => {
    const { isFeatureActive, paintActiveDisc } = await import('../../app/javascript/maplibre/map_index_selection.js')

    const root = {
      nodes: [
        { id: '10', classList: new Set(['destinations-marker']) },
        { id: '11', classList: new Set(['destinations-marker']) }
      ],
      querySelectorAll (sel) {
        assert.equal(sel, '.destinations-marker')
        return this.nodes.map((n) => ({
          id: n.id,
          classList: {
            toggle (cls, on) {
              if (on) n.classList.add(cls)
              else n.classList.delete(cls)
            }
          }
        }))
      }
    }

    assert.equal(isFeatureActive('11', { properties: { id: 11 } }), true)
    assert.equal(isFeatureActive('11', { properties: { id: 10 } }), false)

    paintActiveDisc(root, '11')
    assert.equal(root.nodes[0].classList.has('destinations-marker--active'), false)
    assert.equal(root.nodes[1].classList.has('destinations-marker--active'), true)

    paintActiveDisc(root, null)
    assert.equal(root.nodes[1].classList.has('destinations-marker--active'), false)
  })
})
