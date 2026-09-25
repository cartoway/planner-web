// Copyright © Cartoway
// Wire format from DestinationsMapGeojson: [id, lng, lat, page].
// MapLibre still needs a GeoJSON Feature; expand only after the response is parsed.

export function pointsToFeatures (points) {
  if (!Array.isArray(points)) return []
  return points.map((point) => {
    const id = point[0]
    return {
      type: 'Feature',
      id,
      geometry: { type: 'Point', coordinates: [point[1], point[2]] },
      properties: { id, page: point[3] }
    }
  })
}
