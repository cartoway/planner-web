import { visit as turboVisit } from '@hotwired/turbo'

const trackedFrameIds = new Set()

export function visit (location, options = {}) {
  if (options.frame) trackedFrameIds.add(String(options.frame))
  return turboVisit(location, options)
}

function reloadTrackedFrames () {
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

window.addEventListener('popstate', reloadTrackedFrames)
