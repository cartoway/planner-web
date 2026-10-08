// Copyright © Cartoway
// Bottom-right toast stack for v2 (PNotify-like). Call showToast({ message, className, sticky }).

const STACK_ATTR = 'data-v2-toast-stack'
const TOAST_ATTR = 'data-v2-toast'
const DEFAULT_DELAY_MS = 6000

export function toastStack (doc = document) {
  let stack = doc.querySelector(`[${STACK_ATTR}]`)
  if (stack) return stack

  stack = doc.createElement('div')
  stack.className = 'v2-toast-stack'
  stack.setAttribute(STACK_ATTR, '')
  stack.setAttribute('aria-live', 'polite')
  stack.setAttribute('aria-relevant', 'additions')
  ;(doc.body || doc.documentElement).appendChild(stack)
  return stack
}

function alertVariant (className) {
  const raw = String(className || 'alert-danger').trim()
  // Prefer an explicit Bootstrap alert-* token (do not strip the "alert-" prefix).
  const named = raw.match(/alert-[\w-]+/)
  if (named) return named[0]
  const short = raw.replace(/^alert\s+/i, '').trim()
  return short ? `alert-${short}` : 'alert-danger'
}

export function clearToasts (doc = document) {
  doc.querySelectorAll(`[${TOAST_ATTR}]`).forEach((el) => el.remove())
}

export function showToast ({
  message,
  className = 'alert-danger',
  sticky = false,
  delay = DEFAULT_DELAY_MS
} = {}, doc = document) {
  if (!message) return null

  const stack = toastStack(doc)
  const toast = doc.createElement('div')
  toast.className = `alert ${alertVariant(className)} alert-dismissible fade show v2-toast mb-0`
  toast.setAttribute('role', 'alert')
  toast.setAttribute(TOAST_ATTR, '')

  const text = doc.createElement('span')
  text.className = 'v2-toast-message'
  text.textContent = message
  toast.appendChild(text)

  const close = doc.createElement('button')
  close.type = 'button'
  close.className = 'btn-close'
  close.setAttribute('aria-label', 'Close')
  close.addEventListener('click', () => toast.remove())
  toast.appendChild(close)

  stack.appendChild(toast)

  if (!sticky && delay > 0) {
    window.setTimeout(() => toast.remove(), delay)
  }

  return toast
}
