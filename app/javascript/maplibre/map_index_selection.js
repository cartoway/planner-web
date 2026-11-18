// Copyright © Cartoway
// Shared list↔map selection for index maps (customers / destinations / stores):
// paint the Teritorio disc in place. DOM MapLibre pins stay for position edit only.

/** @param {unknown} activeId @param {{ properties?: { id?: unknown } } | null | undefined} feature */
export function isFeatureActive (activeId, feature) {
  const id = feature && feature.properties && feature.properties.id
  return activeId != null && id != null && String(id) === String(activeId)
}

/**
 * Toggle `.destinations-marker--active` on Teritorio discs (incl. spidered leaves).
 * Disc element `id` is set by Teritorio from the GeoJSON feature id.
 * @param {ParentNode | null | undefined} root
 * @param {unknown} activeId
 */
export function paintActiveDisc (root, activeId) {
  if (!root || typeof root.querySelectorAll !== 'function') return
  const id = activeId != null ? String(activeId) : ''
  root.querySelectorAll('.destinations-marker').forEach((disc) => {
    // Position-edit MapLibre pins are id-less (--dom-pin). Only Teritorio discs participate
    // in selection paint; never strip --active from the edit pin.
    if (!disc.id || (typeof disc.classList.contains === 'function' && disc.classList.contains('destinations-marker--dom-pin'))) return
    disc.classList.toggle('destinations-marker--active', id !== '' && disc.id === id)
  })
}

/**
 * Keep the position-edit DOM pin when clearing list highlight.
 * @param {{ markerId?: unknown } | null | undefined} positionEdit
 * @param {unknown} domMarkerId
 */
export function shouldKeepDomMarkerOnClear (positionEdit, domMarkerId) {
  return !!(positionEdit && domMarkerId != null && String(domMarkerId) === String(positionEdit.markerId))
}

/**
 * Parse a lng/lat pair for position-edit snapshot / restore.
 * @returns {{ lng: number, lat: number } | null}
 */
export function parseLngLat (lng, lat) {
  const lngN = typeof lng === 'number' ? lng : parseFloat(String(lng ?? ''))
  const latN = typeof lat === 'number' ? lat : parseFloat(String(lat ?? ''))
  if (!Number.isFinite(lngN) || !Number.isFinite(latN)) return null
  return { lng: lngN, lat: latN }
}
