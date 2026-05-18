// Copyright © Cartoway
// V2 destinations index: MapLibre map (global from layout) + key:value search debounce.
// Vanilla DOM APIs only — no jQuery.

import { Controller } from '@hotwired/stimulus'
import { visit, navigator as turboNavigator } from '@hotwired/turbo'
import { buildRasterStyle, pickLayers } from 'maplibre/raster_layers'
import { GeocoderIControl } from 'maplibre/geocoder_control'
import { BaseLayerSwitcherIControl } from 'maplibre/base_layer_switcher_control'
import { OverlayLayersToggleIControl } from 'maplibre/overlay_layers_toggle_control'

const DEFAULT_ZOOM = 12
const MIN_CHARS = 3
const DEBOUNCE_MS = 300
/** CSS keyframes name in v2/application.scss (cells of row highlighted after map pin click). */
const MAP_PIN_ROW_ANIMATION_SUBSTRING = 'destinationsRowPinHighlightTd'
/** Fallback if `animationend` does not fire (matches animation duration + margin). */
const MAP_PIN_ROW_FALLBACK_MS = 4500
/** Lat/lng fractional digits aligned with DB/API usage (see `round(6)` in app/api/v01/destinations.rb). */
const LOCATION_COORD_DECIMALS = 6

function roundCoord (value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return value
  const f = 10 ** LOCATION_COORD_DECIMALS
  return Math.round(value * f) / f
}

/** Fixed-width string for form fields (matches persisted float rounding). */
function coordToDbInputString (value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return ''
  return roundCoord(value).toFixed(LOCATION_COORD_DECIMALS)
}

function getMaplibre () {
  return typeof window !== 'undefined' && window.maplibregl ? window.maplibregl : null
}

function createMarkerElement (label) {
  const el = document.createElement('div')
  el.className = 'destinations-v2-marker'
  el.setAttribute('role', 'button')
  if (label) el.setAttribute('aria-label', label)

  const pulse = document.createElement('span')
  pulse.className = 'destinations-v2-marker__pulse'
  pulse.setAttribute('aria-hidden', 'true')

  const head = document.createElement('span')
  head.className = 'destinations-v2-marker__head'

  const glint = document.createElement('span')
  glint.className = 'destinations-v2-marker__glint'
  glint.setAttribute('aria-hidden', 'true')
  head.appendChild(glint)

  const pin = document.createElement('span')
  pin.className = 'destinations-v2-marker__pin'
  pin.setAttribute('aria-hidden', 'true')

  el.appendChild(pulse)
  el.appendChild(head)
  el.appendChild(pin)
  return el
}

function parseKeyValueFilters (input) {
  if (!input || !input.includes(':')) return []
  const result = []
  input.split(/\s+/).forEach((part) => {
    const colonIdx = part.indexOf(':')
    if (colonIdx > 0) {
      const key = part.slice(0, colonIdx).trim()
      const value = part.slice(colonIdx + 1).trim()
      if (key && value) result.push({ key, value, raw: `${key}:${value}` })
    }
  })
  return result
}

function hasMinCharsForSearch (input) {
  if (!input || input.length < MIN_CHARS) return false
  if (input.includes(':')) {
    const parts = input.split(':', 2)
    return (parts[1] || '').trim().length >= MIN_CHARS
  }
  return input.trim().length >= MIN_CHARS
}

export default class extends Controller {
  connect () {
    this._abort = new AbortController()
    const signal = this._abort.signal

    let config = {}
    try {
      const raw = this.element.getAttribute('data-config')
      if (raw) config = JSON.parse(raw)
    } catch (e) {
      return
    }

    this._map = null
    this._markersById = {}
    this._iconOverStack = []
    this._searchDebounce = null
    this._positionEdit = null
    /** @type {{ cell: HTMLElement | null, onEnd: (e: AnimationEvent) => void, timer: number } | null} */
    this._mapPinRowHighlightState = null
    this._onTurboFrameLoad = this._onTurboFrameLoad.bind(this)

    const maplibregl = getMaplibre()
    const mapEl = this.element.querySelector('#map')
    if (maplibregl && mapEl && config.map_layers) {
      this._initMap(maplibregl, mapEl, config, signal)
      const hid = config.highlight_destination_id
      if (hid != null && String(hid) !== '' && String(hid) !== '0') {
        requestAnimationFrame(() => {
          this._focusDestinationInList(String(hid), { flyToMap: false, fromMapPin: true })
          this._stripHighlightParamFromUrl()
        })
      }
    }

    this._initSearch(signal)

    this._onPositionDragToggleDocumentClick = this._onPositionDragToggleDocumentClick.bind(this)
    document.addEventListener('click', this._onPositionDragToggleDocumentClick, { signal })

    document.addEventListener('turbo:before-cache', this._beforeCache, { signal })
    document.addEventListener('turbolinks:before-cache', this._beforeCache, { signal })
    document.addEventListener('turbo:frame-load', this._onTurboFrameLoad, { signal })
  }

  disconnect () {
    this._cancelMapPinRowHighlight()
    if (this._abort) this._abort.abort()
    this._abort = null
    this._teardownMap()
    this._map = null
  }

  /**
   * Turbo fires turbo:before-cache before snapshotting the page. Frame navigations
   * (e.g. list page change from a map marker) also run a Visit with willRender: false
   * to sync history — not a real body swap. Tearing WebGL down there loses the map
   * context while the live DOM is unchanged ("WebGL context was lost").
   */
  _beforeCache = () => {
    const visit = turboNavigator.currentVisit
    if (visit && visit.willRender === false) return
    this._teardownMap()
  }

  _teardownMap () {
    this._teardownPositionEdit()
    this._clearDestinationHighlight()
    const mapEl = this.element.querySelector('#map')
    if (mapEl && mapEl._v2MaplibreMap) {
      try {
        mapEl._v2MaplibreMap.remove()
      } catch (e) { /* ignore */ }
      mapEl._v2MaplibreMap = null
    }
    Object.keys(this._markersById || {}).forEach((id) => {
      try {
        this._markersById[id].marker.remove()
      } catch (e) { /* ignore */ }
    })
    this._markersById = {}
    this._iconOverStack = []
  }

  _clearDestinationHighlight () {
    if (!this.element) return
    this._cancelMapPinRowHighlight()
    this.element.querySelectorAll('tr.destination').forEach((tr) => tr.classList.remove('highlight', 'highlight--map-pin'))
    const markersById = this._markersById || {}
    while (this._iconOverStack && this._iconOverStack.length) {
      const id = this._iconOverStack.pop()
      const m = markersById[id]
      if (m) m.el.classList.remove('destinations-v2-marker--active')
    }
  }

  /**
   * Scroll only inside #destination_box. row.scrollIntoView() also scrolls outer layout
   * (.main-primary overflow-y: auto, window) which breaks the fixed map + list UX after Turbo frame updates.
   */
  _scrollDestinationRowIntoView (row) {
    const box = this.element && this.element.querySelector('#destination_box')
    if (!box || !row || !box.contains(row)) return
    const margin = 8
    const boxRect = box.getBoundingClientRect()
    const rowRect = row.getBoundingClientRect()
    if (rowRect.top < boxRect.top + margin) {
      box.scrollTop += rowRect.top - boxRect.top - margin
    } else if (rowRect.bottom > boxRect.bottom - margin) {
      box.scrollTop += rowRect.bottom - boxRect.bottom + margin
    }
  }

  /**
   * Highlight table row + map pin; optionally fly map to pin. Used for list clicks, marker clicks, and ?highlight_destination_id=.
   * @param {{ flyToMap?: boolean, fromMapPin?: boolean }} [options]
   */
  _focusDestinationInList (idStr, options = {}) {
    const flyToMap = !!options.flyToMap
    const fromMapPin = !!options.fromMapPin
    this._clearDestinationHighlight()
    const markersById = this._markersById || {}
    const m = markersById[idStr]
    if (m) {
      m.el.classList.add('destinations-v2-marker--active')
      this._iconOverStack.push(idStr)
      if (flyToMap && this._map) {
        this._map.flyTo({ center: m.marker.getLngLat(), zoom: Math.max(this._map.getZoom(), 14), duration: 500 })
      }
    }
    const row = Array.from(this.element.querySelectorAll('tr.destination')).find((tr) => tr.getAttribute('data-destination-id') === idStr)
    if (row) {
      row.classList.add('highlight')
      if (fromMapPin) {
        row.classList.add('highlight--map-pin')
        this._scheduleMapPinRowHighlightFade(row)
      }
      this._scrollDestinationRowIntoView(row)
    }
  }

  _cancelMapPinRowHighlight () {
    const s = this._mapPinRowHighlightState
    if (!s) return
    window.clearTimeout(s.timer)
    if (s.cell) s.cell.removeEventListener('animationend', s.onEnd)
    this._mapPinRowHighlightState = null
  }

  /**
   * After a map pin click (or turbo jump to highlighted row), row is bold + tinted; then fades and classes clear.
   * Pin marker can stay active until the user focuses another destination.
   */
  _scheduleMapPinRowHighlightFade (row) {
    this._cancelMapPinRowHighlight()
    let finished = false
    const done = () => {
      if (finished || !row.isConnected) return
      finished = true
      row.classList.remove('highlight', 'highlight--map-pin')
      this._cancelMapPinRowHighlight()
    }
    const onEnd = (e) => {
      const name = e.animationName || ''
      if (!name.includes(MAP_PIN_ROW_ANIMATION_SUBSTRING)) return
      done()
    }
    const cell = row.querySelector('td')
    if (cell) cell.addEventListener('animationend', onEnd)
    const prefersReduced =
      typeof window.matchMedia === 'function' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const timer = window.setTimeout(done, prefersReduced ? 2800 : MAP_PIN_ROW_FALLBACK_MS)
    this._mapPinRowHighlightState = { cell, onEnd, timer }
  }

  _buildDestinationsIndexUrl (overrides = {}) {
    const form = this.element.querySelector('#destinations-search-form')
    const action = (form && form.getAttribute('action')) || window.location.pathname || '/destinations'
    const url = new URL(action, window.location.origin)
    const perInput = form && form.querySelector('input[name="per_page"]')
    if (perInput && perInput.value) url.searchParams.set('per_page', perInput.value)
    if (form) {
      form.querySelectorAll('input[name="filters[]"]').forEach((inp) => {
        if (inp.value) url.searchParams.append('filters[]', inp.value)
      })
    }
    const qInp = this.element.querySelector('#search-query')
    if (qInp && qInp.value.trim()) url.searchParams.set('q', qInp.value.trim())
    Object.entries(overrides).forEach(([key, val]) => {
      if (val === undefined || val === null || val === '') url.searchParams.delete(key)
      else url.searchParams.set(key, String(val))
    })
    return url.toString()
  }

  _stripHighlightParamFromUrl () {
    const url = new URL(window.location.href)
    if (!url.searchParams.has('highlight_destination_id')) return
    url.searchParams.delete('highlight_destination_id')
    window.history.replaceState(window.history.state || {}, '', url.toString())
  }

  /** True when the right sidebar shows the destination/visits form (not the empty placeholder). */
  _isDestinationFormSidebarOpen () {
    const frame = document.getElementById('form_sidebar')
    return !!(frame && frame.querySelector('#destination-form-sidebar'))
  }

  /**
   * If the edit form is already open in turbo-frame#form_sidebar, load another destination's edit
   * partial when the user picks a different row (e.g. map marker). Skips reload when already on that id.
   */
  _navigateFormSidebarToRowIfOpen (row, idStr) {
    if (!row || !this._isDestinationFormSidebarOpen()) return
    const form = document.querySelector('#form_sidebar #destination-form-sidebar')
    const currentId = form && form.getAttribute('data-destination_id')
    if (currentId != null && String(currentId) === String(idStr)) return
    const link = row.querySelector('a[data-turbo-frame="form_sidebar"]')
    const href = link && link.getAttribute('href')
    if (!href) return
    visit(href, { frame: 'form_sidebar' })
  }

  _initMap (maplibregl, container, params, signal) {
    this._teardownPositionEdit()
    if (container._v2MaplibreMap) {
      try { container._v2MaplibreMap.remove() } catch (e) { /* ignore */ }
      container._v2MaplibreMap = null
    }

    const { style, baseLayerIds, overlayToggles } = buildRasterStyle(params.map_layers)
    const centerLng = parseFloat(params.map_lng) || 0
    const centerLat = parseFloat(params.map_lat) || 0
    const zoom = params.map_zoom != null ? Number(params.map_zoom) : DEFAULT_ZOOM

    const map = new maplibregl.Map({
      container,
      style,
      center: [centerLng, centerLat],
      zoom,
      attributionControl: true
    })
    container._v2MaplibreMap = map
    this._map = map

    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right')
    map.addControl(new maplibregl.ScaleControl({ maxWidth: 120, unit: 'metric' }), 'bottom-left')

    if (params.geocoder) {
      const placeholder = (typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.search') : 'Search'
      const emptyMsg = (typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.empty_result') : 'No results'
      map.addControl(new GeocoderIControl(placeholder, emptyMsg), 'top-right')
    }

    const basesOnly = pickLayers(params.map_layers).bases
    if (basesOnly.length > 1) {
      map.addControl(new BaseLayerSwitcherIControl(baseLayerIds, basesOnly), 'top-right')
    }

    if (overlayToggles && overlayToggles.length > 0) {
      const overlayTitle = params.map_overlay_title || 'Overlays'
      map.addControl(new OverlayLayersToggleIControl(overlayToggles, overlayTitle), 'top-right')
    }

    const markersById = {}
    this._markersById = markersById

    ;(params.destinations || []).forEach((d) => {
      if (d.lat == null || d.lng == null) return
      const el = createMarkerElement(d.name || '')
      const marker = new maplibregl.Marker({ element: el, anchor: 'bottom' })
        .setLngLat([d.lng, d.lat])
        .addTo(map)
      el.addEventListener('click', (e) => {
        e.stopPropagation()
        const idStr = String(d.id)
        const row = Array.from(this.element.querySelectorAll('tr.destination')).find((tr) => tr.getAttribute('data-destination-id') === idStr)
        if (row) {
          this._focusDestinationInList(idStr, { flyToMap: false, fromMapPin: true })
          this._navigateFormSidebarToRowIfOpen(row, idStr)
          return
        }
        const rawPage = d.page != null ? d.page : d['page']
        const destPage = Number(rawPage)
        if (Number.isFinite(destPage) && destPage > 0) {
          const visitUrl = this._buildDestinationsIndexUrl({ page: destPage, highlight_destination_id: idStr })
          visit(visitUrl, { frame: 'destinations_list', action: 'advance' })
        } else {
          this._focusDestinationInList(idStr, { flyToMap: false, fromMapPin: true })
        }
      })
      markersById[String(d.id)] = { marker, el, lngLat: [d.lng, d.lat] }
    })

    const coords = Object.keys(markersById).map((id) => markersById[id].lngLat)
    if (coords.length > 0) {
      const bounds = new maplibregl.LngLatBounds(coords[0], coords[0])
      coords.forEach((c) => bounds.extend(c))
      map.fitBounds(bounds, { padding: 48, maxZoom: 15, duration: 0 })
    }

    const sidebar = this.element.querySelector('.destinations-sidebar')
    const scheduleResize = () => { setTimeout(() => map.resize(), 220) }

    this.element.addEventListener('click', (e) => {
      const tr = e.target.closest && e.target.closest('tr.destination[data-destination-id]')
      if (tr) {
        const id = tr.getAttribute('data-destination-id')
        if (!id) return
        // Any click on the list row: highlight + center map on pin (when coordinates exist).
        this._focusDestinationInList(id, { flyToMap: true })
        return
      }
      if (e.target.closest && e.target.closest('.destinations-sidebar-toggle')) {
        if (sidebar) sidebar.classList.add('collapsed')
        scheduleResize()
        return
      }
      if (e.target.closest && e.target.closest('.destinations-sidebar-expand button')) {
        if (sidebar) sidebar.classList.remove('collapsed')
        scheduleResize()
      }
    }, { signal })

    map.once('load', () => { map.resize() })

    // Sidebar form may already be open (e.g. reload); enable draggable pin when applicable.
    const sidebarFrame = document.getElementById('form_sidebar')
    if (sidebarFrame) this._syncPositionEditFromFormSidebar(sidebarFrame)
  }

  _onTurboFrameLoad (event) {
    const frame = event.target
    if (!frame || !frame.id) return
    if (frame.id === 'form_sidebar') {
      this._syncPositionEditFromFormSidebar(frame)
      return
    }
    if (frame.id === 'destinations_list') {
      requestAnimationFrame(() => {
        const url = new URL(window.location.href)
        const hid = url.searchParams.get('highlight_destination_id')
        if (hid) {
          this._normalizeDestinationsPageScroll()
          this._focusDestinationInList(String(hid), { flyToMap: false, fromMapPin: true })
          const row = this.element.querySelector(`tr.destination[data-destination-id="${CSS.escape(String(hid))}"]`)
          if (row) this._navigateFormSidebarToRowIfOpen(row, String(hid))
          this._stripHighlightParamFromUrl()
        }
      })
      if (this._map) setTimeout(() => this._map.resize(), 220)
    }
  }

  /**
   * When opening a highlighted row after a map pin / deep link, reset stray scroll on .main-primary
   * or the window so the list scrollport (#destination_box) receives wheel events again.
   */
  _normalizeDestinationsPageScroll () {
    try {
      const mainPrimary = this.element.closest('.main-primary')
      if (mainPrimary) mainPrimary.scrollTop = 0
      window.scrollTo(0, 0)
    } catch (e) { /* ignore */ }
  }

  /**
   * Snap marker to rounded coordinates and sync list row + destination lat/lng inputs.
   */
  _syncPositionFromMarker (destinationIdStr, marker, rec) {
    if (!marker || !rec) return
    const ll = marker.getLngLat()
    let lat = typeof ll.lat === 'number' ? ll.lat : parseFloat(String(ll.lat))
    let lng = typeof ll.lng === 'number' ? ll.lng : parseFloat(String(ll.lng))
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return
    lat = roundCoord(lat)
    lng = roundCoord(lng)
    try {
      marker.setLngLat({ lng, lat })
    } catch (e) { /* ignore */ }
    rec.lngLat = [lng, lat]
    const latInp = document.getElementById('destination_lat')
    const lngInp = document.getElementById('destination_lng')
    const sync = (input, valueStr) => {
      if (!input) return
      input.value = valueStr
      input.dispatchEvent(new Event('input', { bubbles: true }))
      input.dispatchEvent(new Event('change', { bubbles: true }))
    }
    sync(latInp, coordToDbInputString(lat))
    sync(lngInp, coordToDbInputString(lng))
    const row = this.element.querySelector(`tr.destination[data-destination-id="${destinationIdStr}"]`)
    if (row) {
      row.setAttribute('data-lat', coordToDbInputString(lat))
      row.setAttribute('data-lng', coordToDbInputString(lng))
    }
  }

  _teardownPositionEdit () {
    const state = this._positionEdit
    if (!state) return
    if (state.active) {
      if (state.mapClickHandler && this._map) {
        try { this._map.off('click', state.mapClickHandler) } catch (e) { /* ignore */ }
      }
      try {
        if (state.marker && typeof state.marker.setDraggable === 'function') state.marker.setDraggable(false)
      } catch (e) { /* ignore */ }
      const rec = this._markersById[state.markerId]
      if (rec && rec.el) rec.el.classList.remove('destinations-v2-marker--dragging')
      state.active = false
    }
    if (state.dragEndHandler && state.marker) {
      try { state.marker.off('dragend', state.dragEndHandler) } catch (e) { /* ignore */ }
    }
    try {
      if (state.marker && typeof state.marker.setDraggable === 'function') state.marker.setDraggable(false)
    } catch (e) { /* ignore */ }
    if (state.toggleButton) this._applyPositionDragToggleUi(state.toggleButton, false)
    this._positionEdit = null
  }

  _disablePositionDrag () {
    const state = this._positionEdit
    if (!state || !state.active) return
    if (state.mapClickHandler && this._map) {
      try { this._map.off('click', state.mapClickHandler) } catch (e) { /* ignore */ }
      state.mapClickHandler = null
    }
    try {
      if (state.marker && typeof state.marker.setDraggable === 'function') state.marker.setDraggable(false)
    } catch (e) { /* ignore */ }
    const rec = this._markersById[state.markerId]
    if (rec && rec.el) rec.el.classList.remove('destinations-v2-marker--dragging')
    state.active = false
    if (state.toggleButton) this._applyPositionDragToggleUi(state.toggleButton, false)
  }

  _enablePositionDrag () {
    const state = this._positionEdit
    if (!state || state.active || !this._map) return
    const rec = this._markersById[state.markerId]
    if (!rec || !state.marker) return
    state.mapClickHandler = (e) => {
      if (!this._positionEdit?.active) return
      const t = e.originalEvent && e.originalEvent.target
      if (t && typeof t.closest === 'function') {
        // Clicks on the HTML marker can still surface as map `click`; ignore (drag handles position).
        if (t.closest('.maplibregl-marker') || t.closest('.mapboxgl-marker') || t.closest('.destinations-v2-marker')) return
        // MapLibre UI (zoom, geocoder, layer switcher…): do not move the pin.
        if (t.closest('.maplibregl-ctrl') || t.closest('.mapboxgl-ctrl')) return
      }
      if (!e.lngLat) return
      const mid = this._positionEdit.markerId
      const m = this._positionEdit.marker
      const r = this._markersById[mid]
      if (!m || !r) return
      try {
        m.setLngLat(e.lngLat)
      } catch (err) { /* ignore */ }
      this._syncPositionFromMarker(mid, m, r)
    }
    this._map.on('click', state.mapClickHandler)
    try {
      state.marker.setDraggable(true)
    } catch (e) { /* ignore */ }
    rec.el.classList.add('destinations-v2-marker--dragging')
    state.active = true
    if (state.toggleButton) this._applyPositionDragToggleUi(state.toggleButton, true)
  }

  _togglePositionDragMode (btn) {
    const state = this._positionEdit
    if (!state) return
    if (btn) state.toggleButton = btn
    if (state.active) this._disablePositionDrag()
    else this._enablePositionDrag()
  }

  _applyPositionDragToggleUi (btn, active) {
    if (!btn) return
    const icon = btn.querySelector('i')
    const idle = btn.dataset.titleIdle
    const on = btn.dataset.titleActive
    btn.setAttribute('aria-pressed', active ? 'true' : 'false')
    if (idle && on) btn.setAttribute('title', active ? on : idle)
    if (icon) {
      icon.className = active ? 'fa fa-times fa-fw' : 'fa fa-location-crosshairs fa-fw'
    }
  }

  _onPositionDragToggleDocumentClick (e) {
    const btn = e.target.closest('[data-v2-map-position-drag-toggle]')
    if (!btn) return
    const form = document.getElementById('destination-form-sidebar')
    if (!form || !form.contains(btn)) return
    if (!this._positionEdit || btn.classList.contains('d-none')) return
    const fid = form.getAttribute('data-destination_id')
    if (fid == null || String(fid) !== String(this._positionEdit.markerId)) return
    e.preventDefault()
    e.stopPropagation()
    this._togglePositionDragMode(btn)
  }

  /**
   * When the destination edit form is open in turbo-frame#form_sidebar, the list map pin
   * becomes the sole way to adjust coordinates (no embedded Leaflet on the form).
   * Dragging is enabled after the user clicks the crosshairs control; map clicks move the pin; the button toggles off.
   */
  _syncPositionEditFromFormSidebar (frameEl) {
    this._teardownPositionEdit()
    if (!this._map || !frameEl) return

    const form = frameEl.querySelector('#destination-form-sidebar')
    if (!form || form.getAttribute('data-position-editable') !== 'true') return

    const rawId = form.getAttribute('data-destination_id')
    const id = rawId != null ? String(rawId) : ''
    if (!id || id === '0') return

    const toggleButton = form.querySelector('[data-v2-map-position-drag-toggle]')
    const rec = this._markersById[id]
    const marker = rec && rec.marker
    if (toggleButton) {
      if (!rec || !marker || typeof marker.setDraggable !== 'function') {
        toggleButton.classList.add('d-none')
        this._applyPositionDragToggleUi(toggleButton, false)
        return
      }
      toggleButton.classList.remove('d-none')
      this._applyPositionDragToggleUi(toggleButton, false)
    }
    if (!rec || !marker || typeof marker.setDraggable !== 'function') return

    const dragEndHandler = () => {
      this._syncPositionFromMarker(id, marker, rec)
    }

    marker.on('dragend', dragEndHandler)
    this._positionEdit = {
      markerId: id,
      marker,
      dragEndHandler,
      toggleButton: toggleButton || null,
      active: false,
      mapClickHandler: null
    }
  }

  _initSearch (signal) {
    const form = this.element.querySelector('#destinations-search-form')
    const input = this.element.querySelector('#search-query')
    if (!form || !input) return

    const submitForm = (additionalFilters = []) => {
      if (additionalFilters.length) {
        additionalFilters.forEach((raw) => {
          const field = document.createElement('input')
          field.type = 'hidden'
          field.name = 'filters[]'
          field.value = raw
          form.appendChild(field)
        })
        input.value = ''
      }
      form.submit()
    }

    input.addEventListener('input', () => {
      clearTimeout(this._searchDebounce)
      this._searchDebounce = setTimeout(() => {
        this._searchDebounce = null
        if (!hasMinCharsForSearch(input.value)) return
        submitForm()
      }, DEBOUNCE_MS)
    }, { signal })

    input.addEventListener('keydown', (e) => {
      if (e.key !== 'Enter') return
      e.preventDefault()
      const val = input.value.trim()
      const filters = parseKeyValueFilters(val)
      if (filters.length) submitForm(filters.map((f) => f.raw))
      else if (hasMinCharsForSearch(val)) submitForm()
    }, { signal })
  }
}
