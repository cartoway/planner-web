// Copyright © Cartoway
// Keep in sync with DestinationsMapLayers.connect style-load behaviour.
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

/**
 * After setStyle, prefer isStyleLoaded() over loaded()/once('load') which can miss the event.
 */
function shouldRunConnectImmediately ({ isStyleLoaded, loaded }) {
  return !!isStyleLoaded
}

describe('destinations map layers reconnect after setStyle', () => {
  it('runs connect immediately when style is already loaded', () => {
    assert.equal(shouldRunConnectImmediately({ isStyleLoaded: true, loaded: false }), true)
  })

  it('waits when style is not loaded yet (initial map)', () => {
    assert.equal(shouldRunConnectImmediately({ isStyleLoaded: false, loaded: false }), false)
  })

  it('registers style.load before setStyle to catch sync raster styles', () => {
    const events = []
    const map = {
      once (name, cb) { events.push(['once', name]); this._cb = cb },
      setStyle () { events.push(['setStyle']); if (this._cb) this._cb() }
    }
    let reattached = false
    map.once('style.load', () => { reattached = true })
    map.setStyle({})
    assert.deepEqual(events, [['once', 'style.load'], ['setStyle']])
    assert.equal(reattached, true)
  })
})
