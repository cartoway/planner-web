// Shared MapLibre ↔ Turbo lifecycle.
// Cached Turbo snapshots keep a dead WebGL canvas unless we tear the map down on
// turbo:before-cache (but NOT when visit.willRender === false — frame-only history sync).

import { navigator as turboNavigator } from '@hotwired/turbo'

const MAP_KEY = '_v2MaplibreMap'

export function getMaplibre () {
  return typeof window !== 'undefined' && window.maplibregl ? window.maplibregl : null
}

export function mapOnContainer (container) {
  return container ? container[MAP_KEY] || null : null
}

/** Remove a MapLibre instance previously glued to the container. */
export function detachMapFromContainer (container) {
  if (!container) return null
  const map = container[MAP_KEY]
  if (!map) return null
  try { map.remove() } catch (_) { /* already gone */ }
  container[MAP_KEY] = null
  return map
}

/**
 * Build a MapLibre map on `container`, replacing any stale instance.
 * `options` are passed to `new maplibregl.Map` (container is set for you).
 */
export function attachMapToContainer (container, options = {}) {
  const maplibregl = getMaplibre()
  if (!maplibregl || !container) return null

  detachMapFromContainer(container)
  const map = new maplibregl.Map({ container, ...options })
  container[MAP_KEY] = map
  return map
}

/** Resize after Turbo morph / sidebar slide / layout — canvas often wakes at 0×0. */
export function scheduleMapResize (map) {
  if (!map) return
  const run = () => {
    try { map.resize() } catch (_) { /* map already removed */ }
  }
  requestAnimationFrame(run)
  setTimeout(run, 100)
}

/**
 * Bind Turbo events that keep a MapLibre map alive across visits.
 *
 * @param {object} opts
 * @param {() => void} opts.teardown - full controller teardown (markers/layers + map.remove)
 * @param {() => void} [opts.onMorph] - after turbo:morph (refresh data / resize)
 * @param {() => Element|null} [opts.getContainer] - map container; used when protectFromMorph
 * @param {boolean} [opts.protectFromMorph=false] - skip morphing the map container node
 * @param {AbortSignal} [opts.signal] - preferred; auto-removes listeners on abort
 * @returns {{ disconnect: () => void }}
 */
export function bindTurboMapHost ({
  teardown,
  onMorph,
  getContainer,
  protectFromMorph = false,
  signal
} = {}) {
  const onBeforeCache = () => {
    // Frame navigations sync history with willRender:false — do not kill the live map.
    const visit = turboNavigator.currentVisit
    if (visit && visit.willRender === false) return
    teardown?.()
  }

  const onBeforeMorphElement = (event) => {
    if (!protectFromMorph) return
    const container = getContainer?.()
    if (!container || !(event.target instanceof Element)) return
    if (event.target === container) event.preventDefault()
  }

  const onTurboMorph = () => {
    onMorph?.()
    const container = getContainer?.()
    scheduleMapResize(mapOnContainer(container))
  }

  const listeners = [
    ['turbo:before-cache', onBeforeCache, false],
    ['turbolinks:before-cache', onBeforeCache, false]
  ]
  if (onMorph || protectFromMorph) {
    listeners.push(['turbo:morph', onTurboMorph, false])
  }
  if (protectFromMorph) {
    listeners.push(['turbo:before-morph-element', onBeforeMorphElement, true])
  }

  listeners.forEach(([type, handler, capture]) => {
    document.addEventListener(type, handler, { signal, capture })
  })

  return {
    disconnect () {
      if (!signal) {
        listeners.forEach(([type, handler, capture]) => {
          document.removeEventListener(type, handler, capture)
        })
      }
      teardown?.()
    }
  }
}
