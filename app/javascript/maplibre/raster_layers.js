// Copyright © Cartoway
// Shared MapLibre helpers: raster tile URLs + style from a layers hash
// (name -> { url, name, attribution, default, overlay, vector_style_url }).
// vector_style_url must already be a MapLibre style JSON URL (any provider).

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

/** True when at least one base map uses a vector style URL (requires setStyle to switch). */
export function basesNeedStyleSwitch (bases) {
  return (bases || []).some((b) => !!b.vectorStyleUrl)
}

export function styleForBaseLayer (base) {
  if (!base) return null
  if (base.vectorStyleUrl) return base.vectorStyleUrl
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
 * Prefer the default base layer's vector_style_url when present (MapLibre GL style JSON).
 * Falls back to a composite raster style built from url tiles.
 * Overlay toggles always listed; vector overlays are applied later via applyOverlays.
 */
export function resolveMapStyle (mapLayers) {
  const { bases, overlays } = pickLayers(mapLayers)
  const defaultBase = bases.find((b) => b.default) || bases[0]
  if (defaultBase && defaultBase.vectorStyleUrl) {
    const raster = buildRasterStyle(mapLayers)
    return {
      mode: 'vector',
      style: defaultBase.vectorStyleUrl,
      baseLayerIds: raster.baseLayerIds,
      overlayToggles: raster.overlayToggles,
      styleSwitch: true
    }
  }
  const raster = buildRasterStyle(mapLayers)
  return {
    mode: 'raster',
    ...raster,
    styleSwitch: basesNeedStyleSwitch(bases) || overlays.some((o) => o.vectorStyleUrl)
  }
}

function overlayToggleSpec (o, j, layerIds = []) {
  const groupId = 'overlay-' + j
  const ids = layerIds.length ? layerIds : (o.vectorStyleUrl ? [] : [groupId + '-layer'])
  return {
    layerId: groupId,
    layerIds: ids,
    name: o.name,
    initialVisible: !!o.default,
    vectorStyleUrl: o.vectorStyleUrl || null
  }
}

/**
 * Build a MapLibre style object (raster sources/layers) from application layer config.
 * Overlays with vector_style_url are omitted here (merged after load via applyOverlays).
 * @returns {{ style: object, baseLayerIds: string[], overlayToggles: object[] }}
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
    if (o.vectorStyleUrl) {
      overlayToggles.push(overlayToggleSpec(o, j))
      return
    }
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
    overlayToggles.push(overlayToggleSpec(o, j, [layerId]))
  })
  return { style: { version: 8, sources, layers }, baseLayerIds: bases.map((_, i) => 'base-' + i + '-layer'), overlayToggles }
}

async function fetchStyleJson (styleUrl) {
  const res = await fetch(styleUrl, { credentials: 'omit' })
  if (!res.ok) throw new Error(`Overlay style HTTP ${res.status}`)
  return res.json()
}

function resolveStyleResourceUrl (styleUrl, resource) {
  if (!resource) return resource
  if (/^https?:\/\//i.test(resource)) return resource
  try {
    return new URL(resource, styleUrl).toString()
  } catch (e) {
    return resource
  }
}

/**
 * Merge a MapLibre style JSON as an overlay (prefixed sources/layers).
 * Skips background layers and layers authored with visibility:"none"
 * @returns {string[]} layer ids added for this overlay (toggle-controlled)
 */
export function mergeVectorOverlayStyle (map, style, overlayIndex, visible, styleUrl = null) {
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

  const sources = style.sources || {}
  Object.keys(sources).forEach((id) => {
    if (!usedSources.has(id)) return
    const sid = prefix + id
    if (map.getSource(sid)) return
    const raw = { ...sources[id] }
    if (Array.isArray(raw.tiles)) {
      raw.tiles = raw.tiles.map((t) => resolveStyleResourceUrl(styleUrl, t))
    }
    if (raw.url) raw.url = resolveStyleResourceUrl(styleUrl, raw.url)
    map.addSource(sid, raw)
  })
  layers.forEach((layer) => {
    const lid = prefix + layer.id
    layerIds.push(lid)
    if (map.getLayer(lid)) {
      map.setLayoutProperty(lid, 'visibility', visible ? 'visible' : 'none')
      return
    }
    const next = {
      ...layer,
      id: lid,
      layout: { ...(layer.layout || {}) }
    }
    next.layout.visibility = visible ? 'visible' : 'none'
    if (layer.source) next.source = prefix + layer.source
    try {
      map.addLayer(next)
    } catch (e) {
      // Skip layers that the current map glyphs/sprite cannot render.
    }
  })
  return layerIds
}

function applySingleRasterOverlay (map, overlay, index, visible) {
  const sid = 'overlay-' + index
  const layerId = sid + '-layer'
  if (!map.getSource(sid)) {
    map.addSource(sid, {
      type: 'raster',
      tiles: [tileUrlForRaster(overlay.url)],
      tileSize: 256,
      attribution: overlay.attribution || ''
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
  return [layerId]
}

/**
 * Add overlays on an existing map. Prefer vector_style_url (style JSON) over raster url.
 * Mutates overlayToggles entries' layerIds when provided (same object refs as the UI).
 *
 * @param {object} map
 * @param {object[]} overlays from pickLayers
 * @param {Record<string, boolean>} visibilityByGroupId keyed by overlay-N
 * @param {object[]} [overlayToggles]
 * @param {{ includeRaster?: boolean }} [options] includeRaster=false skips raster overlays already baked in composite style
 */
export async function applyOverlays (map, overlays, visibilityByGroupId = {}, overlayToggles = null, options = {}) {
  if (!map || !overlays || !overlays.length) return []
  const includeRaster = options.includeRaster !== false
  const toggles = []
  for (let j = 0; j < overlays.length; j++) {
    const o = overlays[j]
    const groupId = 'overlay-' + j
    const preferred = visibilityByGroupId[groupId]
    const visible = preferred != null ? !!preferred : !!o.default
    let layerIds = []

    if (o.vectorStyleUrl) {
      try {
        const style = await fetchStyleJson(o.vectorStyleUrl)
        layerIds = mergeVectorOverlayStyle(map, style, j, visible, o.vectorStyleUrl)
      } catch (e) {
        // Vector overlays are never baked into the composite style — always allow raster fallback.
        if (o.url) layerIds = applySingleRasterOverlay(map, o, j, visible)
      }
    } else if (includeRaster && o.url) {
      layerIds = applySingleRasterOverlay(map, o, j, visible)
    } else if (!o.vectorStyleUrl && o.url) {
      // Raster already in composite style — keep toggle metadata only.
      layerIds = [groupId + '-layer']
    }

    const spec = overlayToggleSpec(o, j, layerIds)
    spec.initialVisible = visible
    if (overlayToggles && overlayToggles[j]) {
      overlayToggles[j].layerIds = layerIds
      overlayToggles[j].layerId = groupId
    }
    toggles.push(spec)
  }
  return toggles
}

/** @deprecated use applyOverlays */
export function applyRasterOverlays (map, overlays, visibilityByLayerId = {}) {
  const byGroup = {}
  Object.keys(visibilityByLayerId || {}).forEach((key) => {
    const group = key.replace(/-layer$/, '')
    byGroup[group] = visibilityByLayerId[key]
  })
  return applyOverlays(map, overlays, byGroup, null, { includeRaster: true })
}
