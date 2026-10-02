// Copyright © Cartoway
// Operation list/detail are flex siblings of the map. Counting their widths as
// MapLibre padding breaks fitBounds after flyTo (padding accumulates and can
// exceed the canvas — expand / center-route becomes a no-op).
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

function operationMapPadding () {
  return { top: 48, bottom: 48, left: 48, right: 48 }
}

function legacyMapPadding ({ listWidth, detailWidth }) {
  const left = Math.ceil(listWidth) + 16
  let right = 48
  if (detailWidth > 40) right = Math.ceil(detailWidth) + 16
  return { top: 48, bottom: 48, left, right }
}

describe('operation map padding', () => {
  it('stays inside a shrunk map canvas so fitBounds can run after flyTo', () => {
    const mapW = 335 // typical width once the detail panel is open
    const padding = operationMapPadding()
    assert.ok(padding.left + padding.right < mapW)

    const bad = legacyMapPadding({ listWidth: 405, detailWidth: 416 })
    assert.ok(bad.left + bad.right > mapW, 'legacy sibling-as-overlay padding exceeds canvas')
  })
})
