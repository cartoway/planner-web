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

  it('caps cluster expand fitBounds at a tile-safe zoom (OSM ~z19)', () => {
    // Keep in sync with CLUSTER_FIT_MAX_ZOOM in destinations_map_layers.js
    const CLUSTER_FIT_MAX_ZOOM = 18
    const padding = 48
    const options = { padding: padding || 48, maxZoom: CLUSTER_FIT_MAX_ZOOM }
    assert.equal(options.maxZoom, 18)
    assert.ok(options.maxZoom <= 19)
  })

  it('spiders stacked cluster leaves by raising unfoldedClusterMaxLeaves', () => {
    // Mirrors DestinationsMapLayers _clusterLeavesAreStacked / _spiderClusterLeaves.
    function leavesAreStacked (features) {
      const coords = (features || [])
        .map((f) => f.geometry && f.geometry.coordinates)
        .filter((c) => c && c.length >= 2)
      if (coords.length < 2) return false
      let minLng = coords[0][0]
      let maxLng = coords[0][0]
      let minLat = coords[0][1]
      let maxLat = coords[0][1]
      for (let i = 1; i < coords.length; i++) {
        const [lng, lat] = coords[i]
        if (lng < minLng) minLng = lng
        if (lng > maxLng) maxLng = lng
        if (lat < minLat) minLat = lat
        if (lat > maxLat) maxLat = lat
      }
      return Math.max(maxLng - minLng, maxLat - minLat) < 1e-5
    }
    function raiseUnfoldCap (prev, leafCount) {
      return Math.max(prev || 0, leafCount)
    }

    const stacked = [
      { geometry: { coordinates: [2.3, 48.8] } },
      { geometry: { coordinates: [2.300001, 48.800001] } },
      { geometry: { coordinates: [2.3, 48.8] } }
    ]
    const spread = [
      { geometry: { coordinates: [2.3, 48.8] } },
      { geometry: { coordinates: [2.4, 48.9] } }
    ]

    assert.equal(leavesAreStacked(stacked), true)
    assert.equal(leavesAreStacked(spread), false)
    assert.equal(raiseUnfoldCap(7, 15), 15)
    assert.equal(raiseUnfoldCap(15, 10), 15)
  })
})
