// Copyright © Cartoway
// HTML pin used by the v2 destinations/stores map (selected pin and Teritorio markers).

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
  return fillDestinationMarker(el, { name: label, anchored: false })
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
  if (n >= 100) return 52
  if (n >= 25) return 44
  return 36
}
