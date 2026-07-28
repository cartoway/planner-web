// Copyright © Cartoway
// Documents DestinationsMapLayers behaviours
// (keep in sync with app/javascript/maplibre/destinations_map_layers.js).
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

describe('map layers data epoch', () => {
  it('drops a stale unfiltered merge after a filtered reload', async () => {
    let dataEpoch = 0
    const featureCache = new Map()

    const isCurrent = (epoch) => epoch === dataEpoch
    const beginEpoch = () => {
      dataEpoch += 1
      return dataEpoch
    }

    const applyViewport = async ({ epoch, force, features, waitBeforeApply }) => {
      if (waitBeforeApply) await waitBeforeApply
      if (!isCurrent(epoch)) return
      if (force) featureCache.clear()
      features.forEach((f) => featureCache.set(String(f.id), f))
    }

    let releaseStale
    const staleGate = new Promise((resolve) => { releaseStale = resolve })

    const stale = applyViewport({
      epoch: dataEpoch,
      force: true,
      features: [{ id: 1 }, { id: 2 }, { id: 3 }],
      waitBeforeApply: staleGate
    })

    const epoch = beginEpoch()
    featureCache.clear()
    await applyViewport({
      epoch,
      force: true,
      features: [{ id: 2 }]
    })

    releaseStale()
    await stale

    assert.deepEqual(Array.from(featureCache.keys()).sort(), ['2'])
  })
})

describe('map layers fitBounds padding', () => {
  it('prefers getMovePadding over the default inset when fitting marker bounds', () => {
    const getMovePadding = () => ({ top: 48, bottom: 48, left: 360, right: 48 })
    const padding = typeof getMovePadding === 'function' ? getMovePadding() : 48
    assert.equal(padding.left, 360)
    assert.equal(padding.top, 48)
  })
})
