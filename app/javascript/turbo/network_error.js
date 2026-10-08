// Copyright © Cartoway
// Surface Turbo network failures (silent console.error by default) and reset stuck UI.
import { showToast } from 'lib/toast'

const DEFAULT_MESSAGE = 'The server is unavailable. Please try again.'

export function networkErrorMessage (doc = document) {
  const meta = doc.querySelector('meta[name="turbo-network-error-message"]')
  const text = meta?.getAttribute('content')?.trim()
  return text || DEFAULT_MESSAGE
}

export function showNetworkAlert (message, doc = document) {
  return showToast({
    message,
    className: 'alert-danger',
    sticky: true
  }, doc)
}

export function restoreFormSidebar (frame, doc = document) {
  if (!frame) return
  const tpl = doc.getElementById('form-sidebar-placeholder-template')
  frame.removeAttribute('src')
  frame.removeAttribute('busy')
  frame.removeAttribute('aria-busy')
  if (tpl?.content) {
    frame.replaceChildren(tpl.content.cloneNode(true))
  } else {
    frame.replaceChildren()
  }
  frame.dispatchEvent(new CustomEvent('turbo:frame-load', { bubbles: true }))
}

export function resetTurboUi (target, doc = document) {
  doc.documentElement?.removeAttribute('aria-busy')
  doc.querySelectorAll('turbo-frame[busy]').forEach((frame) => {
    frame.removeAttribute('busy')
    frame.removeAttribute('aria-busy')
  })

  if (target?.localName === 'form') {
    target.removeAttribute('aria-busy')
    return
  }

  const frame = target?.localName === 'turbo-frame'
    ? target
    : target?.closest?.('turbo-frame')

  if (frame?.id === 'form_sidebar') {
    restoreFormSidebar(frame, doc)
  } else if (frame) {
    // Drop failed navigation src so the frame is not left mid-load.
    frame.removeAttribute('src')
  }
}

export function handleTurboFetchRequestError (event, doc = document) {
  resetTurboUi(event.target, doc)
  showNetworkAlert(networkErrorMessage(doc), doc)
}

export function installTurboNetworkErrorHandling (doc = document) {
  doc.addEventListener('turbo:fetch-request-error', (event) => {
    handleTurboFetchRequestError(event, doc)
  })
}
