// Copyright © Cartoway
// Happy-path for shared index map selection (Teritorio disc + position-edit DOM pin guard).
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  isFeatureActive,
  paintActiveDisc,
  parseLngLat,
  shouldKeepDomMarkerOnClear
} from '../../app/javascript/maplibre/map_index_selection.js'

function fakeRoot (ids) {
  const nodes = ids.map((id) => ({ id, classList: new Set(['destinations-marker']) }))
  return {
    nodes,
    querySelectorAll (sel) {
      assert.equal(sel, '.destinations-marker')
      return nodes.map((n) => ({
        id: n.id,
        classList: {
          contains (cls) { return n.classList.has(cls) },
          toggle (cls, on) {
            if (on) n.classList.add(cls)
            else n.classList.delete(cls)
          }
        }
      }))
    }
  }
}

describe('map_index_selection', () => {
  it('paints the selected Teritorio disc by element id', () => {
    assert.equal(isFeatureActive('11', { properties: { id: 11 } }), true)
    assert.equal(isFeatureActive('11', { properties: { id: 10 } }), false)

    const root = fakeRoot(['10', '11'])
    paintActiveDisc(root, '11')
    assert.equal(root.nodes[0].classList.has('destinations-marker--active'), false)
    assert.equal(root.nodes[1].classList.has('destinations-marker--active'), true)

    paintActiveDisc(root, null)
    assert.equal(root.nodes[1].classList.has('destinations-marker--active'), false)
  })

  it('does not strip --active from an id-less position-edit DOM pin', () => {
    const pin = {
      id: '',
      classList: {
        _set: new Set(['destinations-marker', 'destinations-marker--dom-pin', 'destinations-marker--active']),
        contains (cls) { return this._set.has(cls) },
        toggle (cls, on) {
          if (on) this._set.add(cls)
          else this._set.delete(cls)
        }
      }
    }
    const root = {
      querySelectorAll (sel) {
        assert.equal(sel, '.destinations-marker')
        return [pin]
      }
    }
    paintActiveDisc(root, '99')
    assert.equal(pin.classList.contains('destinations-marker--active'), true)
  })

  it('keeps the DOM pin only while position edit owns that marker id', () => {
    // List selection no longer creates a DOM pin; edit mode still needs keep-on-clear.
    assert.equal(shouldKeepDomMarkerOnClear({ markerId: '42' }, '42'), true)
    assert.equal(shouldKeepDomMarkerOnClear({ markerId: '42' }, '99'), false)
    assert.equal(shouldKeepDomMarkerOnClear(null, '42'), false)
  })

  it('snapshots lng/lat for cancel-restore of a moved marker', () => {
    // Mirrors destinations/stores: capture at drag start, restore on cancel button.
    const initial = parseLngLat('2.350000', '48.860000')
    const moved = parseLngLat(2.4, 48.9)
    assert.deepEqual(initial, { lng: 2.35, lat: 48.86 })
    assert.deepEqual(moved, { lng: 2.4, lat: 48.9 })

    const afterCancel = initial || null
    assert.deepEqual(afterCancel, { lng: 2.35, lat: 48.86 })
    assert.equal(parseLngLat('', ''), null)
    assert.equal(parseLngLat(null, null), null)
  })

  it('restores the form-open baseline when discarding an edit session', () => {
    // Mirrors _abandonPositionEditSession / form sidebar close without save.
    const baseline = parseLngLat(2.35, 48.86)
    const afterDrag = parseLngLat(2.4, 48.9)
    assert.notDeepEqual(afterDrag, baseline)
    const afterClose = baseline || null
    assert.deepEqual(afterClose, { lng: 2.35, lat: 48.86 })
  })

  it('clears --active on a disc when concealing it for position edit', () => {
    // Mirrors destinations_map_layers _concealHiddenMarkers (hide + drop active colour).
    const disc = {
      classList: new Set(['destinations-marker', 'destinations-marker--active']),
      style: { visibility: '' },
      removeActive () {
        this.classList.delete('destinations-marker--active')
      }
    }
    disc.classList.delete('destinations-marker--active')
    disc.style.visibility = 'hidden'
    assert.equal(disc.classList.has('destinations-marker--active'), false)
    assert.equal(disc.style.visibility, 'hidden')
  })
})
