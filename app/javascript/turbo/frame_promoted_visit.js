import { visit as turboVisit } from '@hotwired/turbo'
import {
  loadTrackedFrameIdsForPage,
  pageKeyForLocation,
  restoreTrackedFrameIds,
  saveTrackedFrameIdsForPage,
  shouldRestoreTrackedFrames
} from 'turbo/frame_tracking_store'

const trackedFrameIds = new Set()
restoreTrackedFrameIds(trackedFrameIds)

function isV2Document () {
  return document.body?.classList?.contains('cartoway-v2')
}

export function visit (location, options = {}) {
  if (options.frame) {
    const frameId = String(options.frame)
    const href = new URL(String(location), window.location.href).href

    trackedFrameIds.add(frameId)
    saveTrackedFrameIdsForPage(trackedFrameIds)
    saveTrackedFrameIdsForPage(trackedFrameIds, pageKeyForLocation(href))

    if (options.action === 'advance') {
      window.history.pushState({ turboFrameId: frameId }, '', href)
    } else if (options.action === 'replace') {
      window.history.replaceState({ turboFrameId: frameId }, '', href)
    }

    const frame = document.getElementById(frameId)
    if (!frame) return turboVisit(location, options)

    if (frame.getAttribute('src') === href && typeof frame.reload === 'function') {
      frame.reload()
    } else {
      frame.setAttribute('src', href)
    }

    return Promise.resolve()
  }

  return turboVisit(location, options)
}

function reloadTrackedFrames () {
  restoreTrackedFrameIds(trackedFrameIds)
  trackedFrameIds.forEach((id) => {
    const frame = document.getElementById(id)
    if (!frame) return
    const href = window.location.href
    if (frame.getAttribute('src') === href && typeof frame.reload === 'function') {
      frame.reload()
    } else {
      frame.setAttribute('src', href)
    }
  })
}

function restoreTrackedFrames (event) {
  if (!shouldRestoreTrackedFrames(event)) return

  // On popstate, decide synchronously before Turbo Drive starts a soft visit.
  if (event.type === 'popstate') {
    const restoredIds = loadTrackedFrameIdsForPage()
    if (restoredIds.length === 0 && !event.state?.turboFrameId && isV2Document()) {
      // History left frame-promoted URLs but the v2 document is still painted (e.g. back to v1).
      window.location.reload()
      return
    }
  }

  window.requestAnimationFrame(() => {
    reloadTrackedFrames()
  })
}

window.addEventListener('popstate', restoreTrackedFrames, true)
window.addEventListener('pageshow', restoreTrackedFrames)
