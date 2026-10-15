// Copyright © Cartoway
// Keep body[data-controller]/[data-action] in sync with turbo-frame#main navigations.
// V2 CSS keys off those body attrs; Turbo only swaps #main, so they otherwise go stale.

export function syncV2BodyPageFromMain (doc = document) {
  const main = doc.getElementById('main')
  const marker = main?.querySelector?.('[data-v2-body-page]')
  const body = doc.body
  if (!marker || !body) return

  const controller = marker.getAttribute('data-v2-body-controller')
  const action = marker.getAttribute('data-v2-body-action')
  if (!controller || !action) return

  body.setAttribute('data-controller', controller)
  body.setAttribute('data-action', action)
}

export function installV2BodyPageSync (doc = document) {
  const main = doc.getElementById('main')
  if (!main || main.dataset.v2BodyPageSync === '1') return
  main.dataset.v2BodyPageSync = '1'

  main.addEventListener('turbo:frame-load', (event) => {
    if (event.target === main) syncV2BodyPageFromMain(doc)
  })
  syncV2BodyPageFromMain(doc)
}
