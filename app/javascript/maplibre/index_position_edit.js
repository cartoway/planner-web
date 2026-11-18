// Copyright © Cartoway
// Shared index position-edit session + drag chrome (destinations / stores).

import { parseLngLat } from './map_index_selection.js'

export function roundCoord (value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return value
  return Math.round(value * 1e6) / 1e6 // DB / API precision (see app/api/v01/destinations.rb)
}

/** Fixed-width string for form fields (matches persisted float rounding). */
export function coordToDbInputString (value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return ''
  return roundCoord(value).toFixed(6)
}

/** Run fn after a slide-panel CSS transition, or immediately if none fires. */
export function afterSlideTransition (el, fn) {
  if (!el) {
    fn()
    return
  }
  let settled = false
  const finish = () => {
    if (settled) return
    settled = true
    el.removeEventListener('transitionend', onEnd)
    clearTimeout(fallbackId)
    fn()
  }
  const onEnd = (e) => {
    if (e.target !== el || e.propertyName !== 'transform') return
    finish()
  }
  el.addEventListener('transitionend', onEnd)
  const fallbackId = setTimeout(finish, 500)
}

/**
 * @param {{
 *   latId: string,
 *   lngId: string,
 *   nameId: string,
 *   rowSelector: (id: string) => string,
 *   formSidebarId: string,
 *   formIdAttr: string,
 *   collapseSidebar: (host: object, onDone: () => void) => boolean
 * }} config
 */
export function createPositionEditBindings (config) {
  const { latId, lngId, nameId, rowSelector, formSidebarId, formIdAttr, collapseSidebar } = config

  function readEditLngLat (domMarker) {
    const fromForm = parseLngLat(
      document.getElementById(lngId)?.value,
      document.getElementById(latId)?.value
    )
    if (fromForm) return fromForm
    if (domMarker && typeof domMarker.getLngLat === 'function') {
      const ll = domMarker.getLngLat()
      return parseLngLat(ll?.lng, ll?.lat)
    }
    return null
  }

  function applyEditLngLat (host, lngLat) {
    const state = host._positionEdit
    if (!state) return
    const id = state.markerId
    if (!lngLat) {
      const sync = (input) => {
        if (!input) return
        input.value = ''
        input.dispatchEvent(new Event('input', { bubbles: true }))
        input.dispatchEvent(new Event('change', { bubbles: true }))
      }
      sync(document.getElementById(latId))
      sync(document.getElementById(lngId))
      const row = host.element.querySelector(rowSelector(id))
      if (row) {
        row.removeAttribute('data-lat')
        row.removeAttribute('data-lng')
      }
      if (host._domMarkerId === id) {
        host._removeDomMarker()
        host._syncHiddenGeojsonPins()
      }
      return
    }
    const nameInp = document.getElementById(nameId)
    host._showDomMarker(id, {
      name: nameInp ? nameInp.value : '',
      lngLat: [lngLat.lng, lngLat.lat],
      active: true
    })
    syncPositionFromMarker(host, id, host._domMarker)
  }

  function restoreMapCoordsOnly (host, idStr, lngLat) {
    const id = String(idStr)
    const row = host.element.querySelector(rowSelector(id))
    if (!lngLat) {
      if (row) {
        row.removeAttribute('data-lat')
        row.removeAttribute('data-lng')
      }
      return
    }
    if (host._mapLayers) host._mapLayers.updateDestinationCoords(id, lngLat.lng, lngLat.lat)
    if (row) {
      row.setAttribute('data-lat', coordToDbInputString(lngLat.lat))
      row.setAttribute('data-lng', coordToDbInputString(lngLat.lng))
    }
  }

  function syncPositionFromMarker (host, idStr, marker) {
    if (!marker) return
    const ll = marker.getLngLat()
    let lat = typeof ll.lat === 'number' ? ll.lat : parseFloat(String(ll.lat))
    let lng = typeof ll.lng === 'number' ? ll.lng : parseFloat(String(ll.lng))
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return
    lat = roundCoord(lat)
    lng = roundCoord(lng)
    try { marker.setLngLat({ lng, lat }) } catch (e) { /* ignore */ }
    if (host._mapLayers) host._mapLayers.updateDestinationCoords(idStr, lng, lat)
    const sync = (input, valueStr) => {
      if (!input) return
      input.value = valueStr
      input.dispatchEvent(new Event('input', { bubbles: true }))
      input.dispatchEvent(new Event('change', { bubbles: true }))
    }
    sync(document.getElementById(latId), coordToDbInputString(lat))
    sync(document.getElementById(lngId), coordToDbInputString(lng))
    const row = host.element.querySelector(rowSelector(idStr))
    if (row) {
      row.setAttribute('data-lat', coordToDbInputString(lat))
      row.setAttribute('data-lng', coordToDbInputString(lng))
    }
  }

  function refreshPositionEditMarker (host) {
    const state = host._positionEdit
    if (!state) return
    if (host._domMarkerId === state.markerId && host._domMarker) state.marker = host._domMarker
  }

  function positionDragCancelButtonLeftPx (host) {
    const layout = host.element
    const layoutRect = layout.getBoundingClientRect()
    let visibleRight = layoutRect.right
    const formSidebar = document.querySelector('.form-sidebar')
    if (formSidebar && !formSidebar.classList.contains('slide-panel--collapsed')) {
      const formRect = formSidebar.getBoundingClientRect()
      if (formRect.left < visibleRight) visibleRight = formRect.left
    }
    return layoutRect.left + (visibleRight - layoutRect.left) / 2 - layoutRect.left
  }

  function syncPositionDragCancelButtonPosition (host) {
    const cancelBtn = host.element.querySelector('.destinations-position-drag-cancel')
    if (!cancelBtn || cancelBtn.classList.contains('d-none')) return
    cancelBtn.style.left = `${positionDragCancelButtonLeftPx(host)}px`
  }

  function setMapPositionDragCursor (host, active) {
    const canvas = host._map && typeof host._map.getCanvas === 'function' ? host._map.getCanvas() : null
    if (canvas) canvas.style.cursor = active ? 'crosshair' : ''
  }

  function syncPositionDragLayout (host, active) {
    const layout = host.element
    const sidebar = layout.querySelector('.destinations-sidebar')
    const cancelBtn = layout.querySelector('.destinations-position-drag-cancel')
    const state = host._positionEdit
    if (active) {
      layout.classList.add('destinations-map-layout--position-drag')
      const collapsed = collapseSidebar(host, () => syncPositionDragCancelButtonPosition(host))
      if (state) state.listSidebarHiddenForDrag = collapsed
      if (cancelBtn) cancelBtn.classList.remove('d-none')
      setMapPositionDragCursor(host, true)
      if (typeof requestAnimationFrame === 'function') {
        requestAnimationFrame(() => syncPositionDragCancelButtonPosition(host))
      } else {
        syncPositionDragCancelButtonPosition(host)
      }
      return
    }
    layout.classList.remove('destinations-map-layout--position-drag')
    setMapPositionDragCursor(host, false)
    if (state?.listSidebarHiddenForDrag && sidebar) {
      sidebar.classList.remove('slide-panel--collapsed')
      state.listSidebarHiddenForDrag = false
      afterSlideTransition(sidebar, () => { if (host._map) host._map.resize() })
    }
    if (cancelBtn) {
      cancelBtn.classList.add('d-none')
      cancelBtn.style.left = ''
    }
  }

  function applyPositionDragToggleUi (btn, active) {
    if (!btn) return
    const icon = btn.querySelector('i')
    const idle = btn.dataset.titleIdle
    const on = btn.dataset.titleActive
    btn.setAttribute('aria-pressed', active ? 'true' : 'false')
    if (idle && on) btn.setAttribute('title', active ? on : idle)
    if (icon) icon.className = active ? 'fa fa-times fa-fw' : 'fa fa-location-crosshairs fa-fw'
  }

  function teardownPositionEdit (host) {
    const state = host._positionEdit
    if (!state) return
    if (state.active) {
      if (state.mapClickHandler && host._map) {
        try { host._map.off('click', state.mapClickHandler) } catch (e) { /* ignore */ }
      }
      try {
        if (state.marker && typeof state.marker.setDraggable === 'function') state.marker.setDraggable(false)
      } catch (e) { /* ignore */ }
      if (host._domMarkerEl) host._domMarkerEl.classList.remove('destinations-marker--dragging')
      state.active = false
    }
    if (state.dragEndHandler && state.marker) {
      try { state.marker.off('dragend', state.dragEndHandler) } catch (e) { /* ignore */ }
    }
    try {
      if (state.marker && typeof state.marker.setDraggable === 'function') state.marker.setDraggable(false)
    } catch (e) { /* ignore */ }
    if (state.toggleButton) applyPositionDragToggleUi(state.toggleButton, false)
    syncPositionDragLayout(host, false)
    host._positionEdit = null
  }

  function disablePositionDrag (host) {
    const state = host._positionEdit
    if (!state || !state.active) return
    if (state.mapClickHandler && host._map) {
      try { host._map.off('click', state.mapClickHandler) } catch (e) { /* ignore */ }
      state.mapClickHandler = null
    }
    try {
      if (state.marker && typeof state.marker.setDraggable === 'function') state.marker.setDraggable(false)
    } catch (e) { /* ignore */ }
    if (host._domMarkerEl) host._domMarkerEl.classList.remove('destinations-marker--dragging')
    state.active = false
    syncPositionDragLayout(host, false)
    if (state.toggleButton) applyPositionDragToggleUi(state.toggleButton, false)
  }

  function applyPlacementClick (host, lngLat) {
    const state = host._positionEdit
    if (!state || !lngLat) return
    if (!state.marker || host._domMarkerId !== state.markerId) {
      const nameInp = document.getElementById(nameId)
      host._showDomMarker(state.markerId, {
        name: nameInp ? nameInp.value : '',
        lngLat: [lngLat.lng, lngLat.lat],
        active: true
      })
    } else {
      try { state.marker.setLngLat(lngLat) } catch (err) { /* ignore */ }
    }
    syncPositionFromMarker(host, state.markerId, host._domMarker)
  }

  function enablePositionDrag (host) {
    const state = host._positionEdit
    if (!state || state.active || !host._map) return
    refreshPositionEditMarker(host)
    state.initialLngLat = readEditLngLat(host._domMarker)
    state.mapClickHandler = (e) => {
      if (!host._positionEdit?.active) return
      const t = e.originalEvent && e.originalEvent.target
      if (t && typeof t.closest === 'function') {
        if (t.closest('.maplibregl-marker') || t.closest('.mapboxgl-marker') || t.closest('.destinations-marker')) return
        if (t.closest('.maplibregl-ctrl') || t.closest('.mapboxgl-ctrl')) return
      }
      if (!e.lngLat) return
      applyPlacementClick(host, e.lngLat)
    }
    host._map.on('click', state.mapClickHandler)
    state.active = true
    if (state.marker && host._domMarkerId === state.markerId && typeof state.marker.setDraggable === 'function') {
      try { state.marker.setDraggable(true) } catch (e) { /* ignore */ }
      if (host._domMarkerEl) host._domMarkerEl.classList.add('destinations-marker--dragging')
    }
    syncPositionDragLayout(host, true)
    if (state.toggleButton) applyPositionDragToggleUi(state.toggleButton, true)
  }

  function togglePositionDragMode (host, btn) {
    const state = host._positionEdit
    if (!state) return
    if (btn) state.toggleButton = btn
    if (state.active) disablePositionDrag(host)
    else enablePositionDrag(host)
  }

  function cancelPositionDrag (host) {
    const state = host._positionEdit
    if (!state || !state.active) return
    applyEditLngLat(host, state.initialLngLat || state.baselineLngLat || null)
    disablePositionDrag(host)
  }

  function abandonSession (host, { clearActiveId, paint }) {
    const state = host._positionEdit
    if (!state) return
    const abandonedId = String(state.markerId)
    restoreMapCoordsOnly(host, abandonedId, state.baselineLngLat || null)
    teardownPositionEdit(host)
    if (host._domMarkerId === abandonedId) {
      host._removeDomMarker()
      host._syncHiddenGeojsonPins()
    }
    clearActiveId()
    paint()
  }

  function forceResetPositionDragChrome (host) {
    const layout = host.element
    if (!layout.classList.contains('destinations-map-layout--position-drag')) return
    layout.classList.remove('destinations-map-layout--position-drag')
    setMapPositionDragCursor(host, false)
    const cancelBtn = layout.querySelector('.destinations-position-drag-cancel')
    if (cancelBtn) {
      cancelBtn.classList.add('d-none')
      cancelBtn.style.left = ''
    }
    const sidebar = layout.querySelector('.destinations-sidebar')
    if (sidebar) {
      sidebar.classList.remove('slide-panel--collapsed')
      afterSlideTransition(sidebar, () => { if (host._map) host._map.resize() })
    }
  }

  function onPositionDragToggleDocumentClick (host, e, { syncFromFormSidebar }) {
    const btn = e.target.closest('[data-v2-map-position-drag-toggle]')
    if (!btn) return
    const form = document.getElementById(formSidebarId)
    if (!form || !form.contains(btn)) return
    if (!host._positionEdit) {
      const frame = document.getElementById('form_sidebar')
      if (frame && syncFromFormSidebar) syncFromFormSidebar(frame)
    }
    if (!host._positionEdit || btn.classList.contains('d-none')) return
    const fid = form.getAttribute(formIdAttr)
    if (fid == null || String(fid) !== String(host._positionEdit.markerId)) return
    refreshPositionEditMarker(host)
    e.preventDefault()
    e.stopPropagation()
    togglePositionDragMode(host, btn)
  }

  return {
    latId,
    lngId,
    nameId,
    readEditLngLat,
    applyEditLngLat,
    restoreMapCoordsOnly,
    syncPositionFromMarker,
    refreshPositionEditMarker,
    syncPositionDragCancelButtonPosition,
    setMapPositionDragCursor,
    syncPositionDragLayout,
    applyPositionDragToggleUi,
    teardownPositionEdit,
    disablePositionDrag,
    enablePositionDrag,
    applyPlacementClick,
    togglePositionDragMode,
    cancelPositionDrag,
    abandonSession,
    forceResetPositionDragChrome,
    onPositionDragToggleDocumentClick,
    afterSlideTransition
  }
}
