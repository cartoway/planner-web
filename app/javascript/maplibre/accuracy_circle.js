// GeoJSON circle in metres around a lng/lat (no turf dependency).

export function accuracyCircleFeature (lng, lat, radiusMeters, steps = 64) {
  const radius = Number(radiusMeters)
  if (!Number.isFinite(lng) || !Number.isFinite(lat) || !Number.isFinite(radius) || radius <= 0) return null

  const coords = []
  const latRad = (lat * Math.PI) / 180
  const mPerDegLat = 111_320
  const mPerDegLng = 111_320 * Math.cos(latRad)
  // Counter-clockwise exterior ring (GeoJSON right-hand rule) so MapLibre fills it.
  for (let i = 0; i <= steps; i += 1) {
    const angle = (i / steps) * 2 * Math.PI
    coords.push([
      lng + (radius * Math.sin(angle)) / mPerDegLng,
      lat + (radius * Math.cos(angle)) / mPerDegLat
    ])
  }
  coords.reverse()
  return {
    type: 'Feature',
    geometry: { type: 'Polygon', coordinates: [coords] },
    properties: {}
  }
}

export function emptyAccuracyCollection () {
  return { type: 'FeatureCollection', features: [] }
}

export function accuracyCollection (lng, lat, radiusMeters) {
  const feature = accuracyCircleFeature(lng, lat, radiusMeters)
  return {
    type: 'FeatureCollection',
    features: feature ? [feature] : []
  }
}

export function ensureAccuracyCircleLayer (map, { sourceId, fillId, lineId, color = '#25417c' } = {}) {
  if (!map || !sourceId || !fillId || !lineId) return
  if (!map.getSource(sourceId)) {
    map.addSource(sourceId, { type: 'geojson', data: emptyAccuracyCollection() })
  }
  if (!map.getLayer(fillId)) {
    map.addLayer({
      id: fillId,
      type: 'fill',
      source: sourceId,
      paint: {
        'fill-color': color,
        'fill-opacity': 0.22
      }
    })
  }
  if (!map.getLayer(lineId)) {
    map.addLayer({
      id: lineId,
      type: 'line',
      source: sourceId,
      paint: {
        'line-color': color,
        'line-width': 2,
        'line-opacity': 0.65
      }
    })
  }
  // Keep the halo above route/track layers (HTML markers stay on top via DOM).
  try {
    map.moveLayer(fillId)
    map.moveLayer(lineId)
  } catch (_) { /* style mid-switch */ }
}

export function setAccuracyCircleData (map, sourceId, lng, lat, radiusMeters) {
  const source = map && map.getSource(sourceId)
  if (!source) return
  source.setData(accuracyCollection(lng, lat, radiusMeters))
}
