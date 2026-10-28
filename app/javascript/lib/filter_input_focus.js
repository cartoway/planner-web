// Copyright © Cartoway
// Remember / restore focus for filter inputs replaced by a Turbo visit.

let pending = null

export function captureFilterFocus (input) {
  if (!input || document.activeElement !== input) {
    pending = null
    return
  }
  pending = {
    id: input.id || null,
    name: input.name || null,
    start: input.selectionStart,
    end: input.selectionEnd
  }
}

export function restoreFilterFocus () {
  const state = pending
  pending = null
  if (!state || typeof document === 'undefined') return false

  const el = (state.id && document.getElementById(state.id)) ||
    (state.name && document.querySelector(`input[name="${CSS.escape(state.name)}"]`)) ||
    null
  if (!el || typeof el.focus !== 'function') return false

  el.focus()
  if (typeof el.setSelectionRange === 'function' && state.start != null && state.end != null) {
    try {
      el.setSelectionRange(state.start, state.end)
    } catch (_) {
      // Some input types reject setSelectionRange.
    }
  }
  return true
}

export function clearFilterFocus () {
  pending = null
}
