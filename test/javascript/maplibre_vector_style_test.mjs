// Copyright © Cartoway
// Keep in sync with app/javascript/maplibre/raster_layers.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

function pickLayers (mapLayers) {
  const keys = Object.keys(mapLayers || {})
  const bases = []
  const overlays = []
  keys.forEach((k) => {
    const L = mapLayers[k]
    const entry = {
      key: k,
      name: L.name || k,
      url: L.url,
      vectorStyleUrl: L.vector_style_url || L.vectorStyleUrl || null,
      attribution: L.attribution || '',
      default: !!L.default,
      overlay: !!L.overlay
    }
    if (entry.overlay) overlays.push(entry)
    else bases.push(entry)
  })
  return { bases, overlays }
}

function resolveMapStyleMode (mapLayers) {
  const { bases } = pickLayers(mapLayers)
  const defaultBase = bases.find((b) => b.default) || bases[0]
  const vectorStyleUrl = defaultBase && defaultBase.vectorStyleUrl
  return vectorStyleUrl ? { mode: 'vector', style: vectorStyleUrl } : { mode: 'raster' }
}

function buildRasterStyle (mapLayers) {
  const { bases, overlays } = pickLayers(mapLayers)
  const sources = {}
  const layers = []
  const overlayToggles = []
  const anyDefault = bases.some((b) => b.default)
  bases.forEach((b, i) => {
    const sid = 'base-' + i
    sources[sid] = { type: 'raster', tiles: [b.url], tileSize: 256 }
    const visible = b.default || (!anyDefault && i === 0)
    layers.push({
      id: sid + '-layer',
      type: 'raster',
      source: sid,
      layout: { visibility: visible ? 'visible' : 'none' }
    })
  })
  overlays.forEach((o, j) => {
    const groupId = 'overlay-' + j
    if (o.vectorStyleUrl) {
      overlayToggles.push({ layerId: groupId, layerIds: [], name: o.name, vectorStyleUrl: o.vectorStyleUrl })
      return
    }
    const layerId = groupId + '-layer'
    sources[groupId] = { type: 'raster', tiles: [o.url], tileSize: 256 }
    layers.push({
      id: layerId,
      type: 'raster',
      source: groupId,
      layout: { visibility: o.default ? 'visible' : 'none' }
    })
    overlayToggles.push({ layerId: groupId, layerIds: [layerId], name: o.name, vectorStyleUrl: null })
  })
  return { style: { version: 8, sources, layers }, overlayToggles }
}

function mergeVectorOverlayStyle (map, style, overlayIndex, visible) {
  const prefix = 'overlay-' + overlayIndex + '-'
  const layerIds = []
  const layers = (style.layers || []).filter((layer) => {
    if (!layer || layer.type === 'background') return false
    if (layer.layout && layer.layout.visibility === 'none') return false
    return true
  })
  const usedSources = new Set()
  layers.forEach((layer) => {
    if (layer.source) usedSources.add(layer.source)
  })
  Object.keys(style.sources || {}).forEach((id) => {
    if (!usedSources.has(id)) return
    const sid = prefix + id
    if (!map.getSource(sid)) map.addSource(sid, { ...style.sources[id] })
  })
  layers.forEach((layer) => {
    const lid = prefix + layer.id
    layerIds.push(lid)
    if (!map.getLayer(lid)) {
      map.addLayer({
        ...layer,
        id: lid,
        source: layer.source ? prefix + layer.source : undefined,
        layout: { ...(layer.layout || {}), visibility: visible ? 'visible' : 'none' }
      })
    }
  })
  return layerIds
}

function fakeMap () {
  const sources = new Map()
  const layers = new Map()
  return {
    getSource: (id) => sources.get(id),
    addSource: (id, src) => { sources.set(id, src) },
    getLayer: (id) => layers.get(id),
    addLayer: (layer) => { layers.set(layer.id, layer) },
    setLayoutProperty: (id, key, value) => {
      const layer = layers.get(id)
      if (layer) {
        layer.layout = layer.layout || {}
        layer.layout[key] = value
      }
    },
    _sources: sources,
    _layers: layers
  }
}

describe('resolveMapStyle prefers vector_style_url as-is', () => {
  it('uses the default base vector_style_url without rewriting the host', () => {
    const styleUrl = 'https://maps.example.com/styles/custom/style.json'
    const resolved = resolveMapStyleMode({
      Custom: {
        name: 'Custom',
        url: 'https://tiles.example.com/{z}/{x}/{y}.png',
        vector_style_url: styleUrl,
        default: true,
        overlay: false
      }
    })
    assert.equal(resolved.mode, 'vector')
    assert.equal(resolved.style, styleUrl)
  })

  it('falls back to raster when vector_style_url is absent', () => {
    const resolved = resolveMapStyleMode({
      Osm: {
        name: 'Osm',
        url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        default: true,
        overlay: false
      }
    })
    assert.equal(resolved.mode, 'raster')
  })

  it('keeps overlay data layers selectable alongside a vector base', () => {
    const layers = {
      VectorBase: {
        name: 'VectorBase',
        url: 'https://tiles.example.com/{z}/{x}/{y}.png',
        vector_style_url: 'https://maps.example.com/style.json',
        default: true,
        overlay: false
      },
      Restrictions: {
        name: 'Restrictions',
        url: 'https://maps.example.com/overlays/truck/{z}/{x}/{y}.png',
        default: false,
        overlay: true
      }
    }
    const overlays = Object.values(layers).filter((l) => l.overlay)
    assert.equal(overlays.length, 1)
    assert.equal(overlays[0].name, 'Restrictions')
  })
})

describe('overlay layers prefer vector_style_url', () => {
  it('omits vector overlays from the composite raster style but keeps toggles', () => {
    const built = buildRasterStyle({
      Osm: {
        name: 'Osm',
        url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        default: true,
        overlay: false
      },
      Truck: {
        name: 'Truck',
        url: 'https://maps.example.com/overlays/truck/{z}/{x}/{y}.png',
        vector_style_url: 'https://maps.example.com/overlays/truck/style.json',
        default: false,
        overlay: true
      }
    })
    assert.equal(Object.keys(built.style.sources).length, 1)
    assert.equal(built.style.layers.length, 1)
    assert.equal(built.overlayToggles.length, 1)
    assert.equal(built.overlayToggles[0].layerId, 'overlay-0')
    assert.equal(built.overlayToggles[0].vectorStyleUrl, 'https://maps.example.com/overlays/truck/style.json')
  })

  it('merges overlay style layers with a prefixed id', () => {
    const map = fakeMap()
    const layerIds = mergeVectorOverlayStyle(map, {
      version: 8,
      sources: {
        restrictions: { type: 'vector', url: 'https://maps.example.com/tiles.json' }
      },
      layers: [
        { id: 'roads', type: 'line', source: 'restrictions', 'source-layer': 'road' },
        { id: 'bg', type: 'background', paint: { 'background-color': '#fff' } }
      ]
    }, 0, true)

    assert.deepEqual(layerIds, ['overlay-0-roads'])
    assert.ok(map.getSource('overlay-0-restrictions'))
    assert.ok(map.getLayer('overlay-0-roads'))
    assert.equal(map.getLayer('overlay-0-roads').layout.visibility, 'visible')
    assert.equal(map.getLayer('overlay-0-bg'), undefined)
  })

  it('skips layers authored with visibility none and their unused sources', () => {
    const map = fakeMap()
    const layerIds = mergeVectorOverlayStyle(map, {
      version: 8,
      sources: {
        restrictions: { type: 'vector', url: 'https://maps.example.com/tiles.json' },
        'osm-carto-raster': { type: 'raster', tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'] }
      },
      layers: [
        { id: 'osm', type: 'raster', source: 'osm-carto-raster', layout: { visibility: 'none' } },
        { id: 'highway', type: 'line', source: 'restrictions', 'source-layer': 'highway' }
      ]
    }, 0, true)

    assert.deepEqual(layerIds, ['overlay-0-highway'])
    assert.ok(map.getSource('overlay-0-restrictions'))
    assert.equal(map.getSource('overlay-0-osm-carto-raster'), undefined)
    assert.equal(map.getLayer('overlay-0-osm'), undefined)
    assert.ok(map.getLayer('overlay-0-highway'))
  })

  it('pickLayers exposes overlay vectorStyleUrl for applyOverlays', () => {
    const { overlays } = pickLayers({
      Truck: {
        name: 'Truck',
        url: 'https://maps.example.com/overlays/truck/{z}/{x}/{y}.png',
        vector_style_url: 'https://maps.example.com/overlays/truck/style.json',
        overlay: true
      }
    })
    assert.equal(overlays.length, 1)
    assert.equal(overlays[0].vectorStyleUrl, 'https://maps.example.com/overlays/truck/style.json')
  })
})
