// Copyright © Cartoway
// Shared MapLibre helpers: raster tile URLs + style from a layers hash
// (name -> { url, name, attribution, default, overlay, vector_url }).

export function tileUrlForRaster (url) {
  if (!url) return url
  let normalized = String(url).replace(/\{s\}/g, 'a')
  // MapLibre fetches raster tiles with XHR/fetch; HTTP tile servers often 301 to HTTPS without CORS headers.
  if (normalized.startsWith('http://')) {
    normalized = `https://${normalized.slice('http://'.length)}`
  }
  return normalized
}

export function pickLayers (mapLayers) {
  const keys = Object.keys(mapLayers || {})
  const bases = []
  const overlays = []
  keys.forEach((k) => {
    const L = mapLayers[k]
    const entry = {
      key: k,
      name: L.name || k,
      url: L.url,
      vectorUrl: L.vector_url || L.vectorUrl || null,
      attribution: L.attribution || '',
      default: !!L.default,
      overlay: !!L.overlay
    }
    if (entry.overlay) overlays.push(entry)
    else bases.push(entry)
  })
  return { bases, overlays }
}

/** True when at least one base map uses a vector style URL (requires setStyle to switch). */
export function basesNeedStyleSwitch (bases) {
  return (bases || []).some((b) => !!b.vectorUrl)
}

export function styleForBaseLayer (base) {
  if (!base) return null
  if (base.vectorUrl) return base.vectorUrl
  return buildRasterStyle({
    [base.key || base.name || 'base']: {
      name: base.name,
      url: base.url,
      attribution: base.attribution,
      default: true,
      overlay: false
    }
  }).style
}

/**
 * Prefer the default base layer's vector_url when present (MapLibre GL style JSON).
 * Falls back to a composite raster style built from url tiles.
 */
export function resolveMapStyle (mapLayers) {
  const { bases, overlays } = pickLayers(mapLayers)
  const defaultBase = bases.find((b) => b.default) || bases[0]
  if (defaultBase && defaultBase.vectorUrl) {
    const raster = buildRasterStyle(mapLayers)
    return {
      mode: 'vector',
      style: defaultBase.vectorUrl,
      baseLayerIds: raster.baseLayerIds,
      overlayToggles: raster.overlayToggles,
      styleSwitch: true
    }
  }
  const raster = buildRasterStyle(mapLayers)
  return {
    mode: 'raster',
    ...raster,
    styleSwitch: basesNeedStyleSwitch(bases) || overlays.some((o) => o.vectorUrl)
  }
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

/**
 * Add/update raster overlay sources+layers on an existing map (e.g. after a vector setStyle).
 * Overlay layer ids match buildRasterStyle: overlay-0-layer, overlay-1-layer, …
 */
export function applyRasterOverlays (map, overlays, visibilityByLayerId = {}) {
  if (!map || !overlays || !overlays.length) return []
  const toggles = []
  overlays.forEach((o, j) => {
    const sid = 'overlay-' + j
    const layerId = sid + '-layer'
    const preferred = visibilityByLayerId[layerId]
    const visible = preferred != null ? !!preferred : !!o.default
    if (!map.getSource(sid)) {
      map.addSource(sid, {
        type: 'raster',
        tiles: [tileUrlForRaster(o.url)],
        tileSize: 256,
        attribution: o.attribution || ''
      })
    }
    if (!map.getLayer(layerId)) {
      map.addLayer({
        id: layerId,
        type: 'raster',
        source: sid,
        layout: { visibility: visible ? 'visible' : 'none' },
        paint: { 'raster-opacity': 0.75 }
      })
    } else {
      map.setLayoutProperty(layerId, 'visibility', visible ? 'visible' : 'none')
    }
    toggles.push({ layerId, name: o.name, initialVisible: visible })
  })
  return toggles
}
