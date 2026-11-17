// Copyright © Cartoway
// Happy-path for shared index position-edit bindings.
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  coordToDbInputString,
  createPositionEditBindings,
  roundCoord
} from '../../app/javascript/maplibre/index_position_edit.js'

function bindingsFor (kind) {
  if (kind === 'store') {
    return createPositionEditBindings({
      latId: 'store_lat',
      lngId: 'store_lng',
      nameId: 'store_name',
      formSidebarId: 'store-form-sidebar',
      formIdAttr: 'data-store_id',
      rowSelector: () => '.store-row',
      collapseSidebar: () => false
    })
  }
  return createPositionEditBindings({
    latId: 'destination_lat',
    lngId: 'destination_lng',
    nameId: 'destination_name',
    formSidebarId: 'destination-form-sidebar',
    formIdAttr: 'data-destination_id',
    rowSelector: (id) => `.destination[data-destination-id="${id}"]`,
    collapseSidebar: () => false
  })
}

describe('index_position_edit', () => {
  it('formats coords for DB inputs', () => {
    assert.equal(roundCoord(1.1234567), 1.123457)
    assert.equal(coordToDbInputString(1.5), '1.500000')
    assert.equal(coordToDbInputString(NaN), '')
  })

  it('abandons a session by restoring baseline and clearing active id', () => {
    const bindings = bindingsFor('destination')
    let painted = false
    let activeId = '42'
    const host = {
      _positionEdit: { markerId: '42', baselineLngLat: { lng: 2.35, lat: 48.86 }, active: false },
      _domMarkerId: null,
      _domMarkerEl: null,
      _map: null,
      element: {
        classList: { add () {}, remove () {}, contains () { return false } },
        querySelector () { return null },
        getBoundingClientRect () { return { left: 0, right: 100 } }
      },
      _mapLayers: null,
      _removeDomMarker () {},
      _syncHiddenGeojsonPins () {}
    }

    bindings.abandonSession(host, {
      clearActiveId: () => { activeId = null },
      paint: () => { painted = true }
    })

    assert.equal(activeId, null)
    assert.equal(painted, true)
    assert.equal(host._positionEdit, null)
  })

  it('toggles drag chrome class via syncPositionDragLayout', () => {
    const classes = new Set()
    const bindings = bindingsFor('store')
    const host = {
      _positionEdit: { listSidebarHiddenForDrag: false },
      _map: null,
      element: {
        classList: {
          add (c) { classes.add(c) },
          remove (c) { classes.delete(c) },
          contains (c) { return classes.has(c) }
        },
        querySelector () { return null },
        getBoundingClientRect () { return { left: 0, right: 200 } }
      }
    }
    bindings.syncPositionDragLayout(host, true)
    assert.equal(classes.has('destinations-map-layout--position-drag'), true)
    bindings.syncPositionDragLayout(host, false)
    assert.equal(classes.has('destinations-map-layout--position-drag'), false)
  })
})
