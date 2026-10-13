// Copyright © Cartoway
// HTML pins + shared MapLibre/Teritorio cluster sizing for destinations, stores, operations.

// GeoJSON source: keep clustering through the last zoom so Teritorio can unfold HTML
// (library README: clusterMaxZoom 22).
export const SOURCE_CLUSTER_MAX_ZOOM = 22
/** Pixel distance between point centres before MapLibre merges them into a cluster. */
export const CLUSTER_RADIUS = 44
// Above map max zoom so large clusters stay a count bubble until clicked.
export const PLUGIN_CLUSTER_MAX_ZOOM = 23
export const UNFOLDED_CLUSTER_MAX_LEAVES = 7
/** Teritorio layout size for individual markers (unfold spacing). */
export const MARKER_SIZE = 22

export const CLUSTER_BUBBLE_SIZE_SMALL = 36
export const CLUSTER_BUBBLE_SIZE_MEDIUM = 44
export const CLUSTER_BUBBLE_SIZE_LARGE = 52

/** Options to spread into a clustered GeoJSON source. */
export function geojsonClusterSourceOptions () {
  return {
    cluster: true,
    clusterMaxZoom: SOURCE_CLUSTER_MAX_ZOOM,
    clusterRadius: CLUSTER_RADIUS
  }
}

/** Base TeritorioCluster options; pass render callbacks via `extra`. */
export function teritorioClusterOptions (extra = {}) {
  return {
    clusterMaxZoom: PLUGIN_CLUSTER_MAX_ZOOM,
    markerSize: MARKER_SIZE,
    unfoldedClusterMaxLeaves: UNFOLDED_CLUSTER_MAX_LEAVES,
    ...extra
  }
}

export function fillDestinationMarker (element, { name, anchored = false } = {}) {
  element.className = anchored ? 'destinations-marker destinations-marker--anchored' : 'destinations-marker'
  element.setAttribute('role', 'button')
  if (name) element.setAttribute('aria-label', name)
  else element.removeAttribute('aria-label')

  element.replaceChildren()

  const head = document.createElement('span')
  head.className = 'destinations-marker__head'

  const glint = document.createElement('span')
  glint.className = 'destinations-marker__glint'
  glint.setAttribute('aria-hidden', 'true')
  head.appendChild(glint)

  const pin = document.createElement('span')
  pin.className = 'destinations-marker__pin'
  pin.setAttribute('aria-hidden', 'true')

  element.appendChild(head)
  element.appendChild(pin)
  return element
}

export function createDestinationMarkerElement (label) {
  const el = document.createElement('div')
  return fillDestinationMarker(el, { name: label, anchored: true })
}

export function fillClusterMarker (element, props) {
  const count = props && (props.point_count_abbreviated != null ? props.point_count_abbreviated : props.point_count)
  element.className = 'destinations-cluster'
  element.setAttribute('role', 'button')
  element.textContent = count != null ? String(count) : ''
  const size = clusterMarkerSize(props && props.point_count)
  element.style.width = `${size}px`
  element.style.height = `${size}px`
  return element
}

export function clusterMarkerSize (pointCount) {
  const n = Number(pointCount) || 0
  if (n >= 100) return CLUSTER_BUBBLE_SIZE_LARGE
  if (n >= 25) return CLUSTER_BUBBLE_SIZE_MEDIUM
  return CLUSTER_BUBBLE_SIZE_SMALL
}
