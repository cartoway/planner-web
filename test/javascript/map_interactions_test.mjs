// Copyright © Cartoway
// Keep in sync with app/javascript/maplibre/map_interactions.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

function disableMapPitchAndRotation (map) {
  if (!map) return

  map.dragRotate.disable()
  map.touchZoomRotate.disableRotation()
  map.touchPitch.disable()
  map.setMaxPitch(0)
  map.setMinPitch(0)
}

describe('disableMapPitchAndRotation', () => {
  it('disables pitch and rotation handlers on the map', () => {
    const calls = []
    const map = {
      dragRotate: { disable () { calls.push('dragRotate') } },
      touchZoomRotate: { disableRotation () { calls.push('touchZoomRotate') } },
      touchPitch: { disable () { calls.push('touchPitch') } },
      setMaxPitch (value) { calls.push(`maxPitch:${value}`) },
      setMinPitch (value) { calls.push(`minPitch:${value}`) }
    }

    disableMapPitchAndRotation(map)

    assert.deepEqual(calls, [
      'dragRotate',
      'touchZoomRotate',
      'touchPitch',
      'maxPitch:0',
      'minPitch:0'
    ])
  })
})
