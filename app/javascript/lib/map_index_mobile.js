// Copyright © Cartoway
// Shared helpers for destinations/stores map indexes: mobile Liste/Carte panes
// and flyTo padding (desktop overlays vs full-bleed mobile map).

export const MAP_INDEX_MOBILE_MQ = '(max-width: 991.98px)'

/** True when the layout uses Liste/Carte panes and the viewport is mobile. */
export function isMapIndexMobileLayout (layoutEl, matchMediaFn = globalThis.matchMedia) {
  if (!layoutEl || typeof matchMediaFn !== 'function') return false
  if (!layoutEl.querySelector('.v2-map-index-mobile-panes')) return false
  return !!matchMediaFn(MAP_INDEX_MOBILE_MQ).matches
}

/**
 * Switch layout to the map pane and sync pane tab buttons.
 * @returns {boolean} true when the pane class actually changed
 */
export function applyMobileMapPane (layoutEl, paneButtons = []) {
  if (!layoutEl) return false
  const already = layoutEl.classList.contains('is-mobile-pane-map')
  layoutEl.classList.toggle('is-mobile-pane-list', false)
  layoutEl.classList.toggle('is-mobile-pane-map', true)
  paneButtons.forEach((button) => {
    const active = button.dataset.pane === 'map'
    button.classList.toggle('btn-primary', active)
    button.classList.toggle('btn-outline-secondary', !active)
    button.setAttribute('aria-selected', active ? 'true' : 'false')
  })
  return !already
}

/**
 * MapLibre flyTo/fitBounds padding.
 * Desktop: compensate left list overlay + right form sidebar.
 * Mobile map pane: no left list; form is a bottom sheet → pad bottom when open.
 */
export function mapIndexFlyToPadding ({
  layoutEl,
  leftSidebar,
  expandBtn,
  formSidebar,
  mobile = false
}) {
  const inset = 48
  const gutter = 16
  const layoutRect = layoutEl.getBoundingClientRect()
  const padding = { top: inset, bottom: inset, left: inset, right: inset }

  if (mobile) {
    if (formSidebar && !formSidebar.classList.contains('slide-panel--collapsed')) {
      const formRect = formSidebar.getBoundingClientRect()
      if (formRect.height > 0) {
        padding.bottom = Math.max(
          inset,
          Math.ceil(layoutRect.bottom - formRect.top) + gutter
        )
      }
    }
    return padding
  }

  if (leftSidebar) {
    if (leftSidebar.classList.contains('slide-panel--collapsed')) {
      if (expandBtn) {
        const expandRect = expandBtn.getBoundingClientRect()
        padding.left = Math.max(
          inset,
          Math.ceil(expandRect.right - layoutRect.left) + gutter
        )
      }
    } else {
      const sidebarRect = leftSidebar.getBoundingClientRect()
      if (sidebarRect.width > 0) {
        padding.left = Math.ceil(sidebarRect.width) + gutter
      }
    }
  }

  if (formSidebar && !formSidebar.classList.contains('slide-panel--collapsed')) {
    const formRect = formSidebar.getBoundingClientRect()
    if (formRect.width > 0) {
      padding.right = Math.max(
        inset,
        Math.ceil(layoutRect.right - formRect.left) + gutter
      )
    }
  }

  return padding
}
