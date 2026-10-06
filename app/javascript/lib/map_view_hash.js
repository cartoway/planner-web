// Copyright © Cartoway
// Leaflet-hash compatible camera in the URL: #zoom/lat/lng (planning v1).

export function parseMapViewHash (hash = typeof window !== 'undefined' ? window.location.hash : '') {
  const raw = String(hash || '').replace(/^#/, '')
  const args = raw.split('/')
  if (args.length !== 3) return null
  const zoom = parseFloat(args[0])
  const lat = parseFloat(args[1])
  const lng = parseFloat(args[2])
  if (![zoom, lat, lng].every(Number.isFinite)) return null
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null
  return { zoom, center: [lng, lat] }
}

export function formatMapViewHash (zoom, lat, lng) {
  // One decimal is enough for MapLibre fractional zoom; keeps the hash short.
  const z = Number(Number(zoom).toFixed(1))
  const precision = Math.max(0, Math.ceil(Math.log(z || 1) / Math.LN2))
  return `#${z}/${Number(lat).toFixed(precision)}/${Number(lng).toFixed(precision)}`
}

export function formatMapViewFromMap (map) {
  const center = map.getCenter()
  return formatMapViewHash(map.getZoom(), center.lat, center.lng)
}

export function replaceMapViewHash (hash, loc = typeof window !== 'undefined' ? window.location : null, historyApi = typeof window !== 'undefined' ? window.history : null) {
  if (!loc || !historyApi) return
  const next = `${loc.pathname}${loc.search}${hash}`
  const current = `${loc.pathname}${loc.search}${loc.hash}`
  if (current === next) return
  historyApi.replaceState(historyApi.state || {}, '', next)
}

export function bindMapViewHash (map) {
  const onMoveEnd = () => replaceMapViewHash(formatMapViewFromMap(map))
  map.on('moveend', onMoveEnd)
  return () => map.off('moveend', onMoveEnd)
}
