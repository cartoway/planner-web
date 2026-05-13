// Copyright © Cartoway
// Shared MapLibre helpers: raster tile URLs + style from a layers hash (name -> { url, name, attribution, default, overlay }).

export function tileUrlForRaster (url) {
  if (!url) return url
  return String(url).replace(/\{s\}/g, 'a')
}

export function pickLayers (mapLayers) {
  const keys = Object.keys(mapLayers || {})
  const bases = []
  const overlays = []
  keys.forEach((k) => {
    const L = mapLayers[k]
    const entry = { key: k, name: L.name || k, url: L.url, attribution: L.attribution || '', default: !!L.default, overlay: !!L.overlay }
    if (entry.overlay) overlays.push(entry)
    else bases.push(entry)
  })
  return { bases, overlays }
}

/**
 * Build a MapLibre style object (raster sources/layers) from application layer config.
 * @returns {{ style: object, baseLayerIds: string[], overlayToggles: { layerId: string, name: string, initialVisible: boolean }[] }}
 */
export function buildRasterStyle (mapLayers) {
  const { bases, overlays } = pickLayers(mapLayers)
  const sources = {}
  const layers = []
  const overlayToggles = []
  const anyDefault = bases.some((b) => b.default)
  bases.forEach((b, i) => {
    const sid = 'base-' + i
    sources[sid] = {
      type: 'raster',
      tiles: [tileUrlForRaster(b.url)],
      tileSize: 256,
      attribution: b.attribution
    }
    const visible = b.default || (!anyDefault && i === 0)
    layers.push({
      id: sid + '-layer',
      type: 'raster',
      source: sid,
      layout: { visibility: visible ? 'visible' : 'none' }
    })
  })
  overlays.forEach((o, j) => {
    const sid = 'overlay-' + j
    const layerId = sid + '-layer'
    const visible = !!o.default
    sources[sid] = {
      type: 'raster',
      tiles: [tileUrlForRaster(o.url)],
      tileSize: 256,
      attribution: o.attribution
    }
    layers.push({
      id: layerId,
      type: 'raster',
      source: sid,
      layout: { visibility: visible ? 'visible' : 'none' },
      paint: { 'raster-opacity': 0.75 }
    })
    overlayToggles.push({ layerId, name: o.name, initialVisible: visible })
  })
  return { style: { version: 8, sources, layers }, baseLayerIds: bases.map((_, i) => 'base-' + i + '-layer'), overlayToggles }
}
