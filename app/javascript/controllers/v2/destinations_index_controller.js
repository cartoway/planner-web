// Copyright © Cartoway
// V2 destinations index: MapLibre map (global from layout) + key:value search debounce.
// Vanilla DOM APIs only — no jQuery.

import { Controller } from '@hotwired/stimulus'
import { visit, navigator as turboNavigator } from '@hotwired/turbo'
import { buildRasterStyle, pickLayers } from 'maplibre/raster_layers'
import { GeocoderIControl } from 'maplibre/geocoder_control'
import { OverlayLayersToggleIControl } from 'maplibre/overlay_layers_toggle_control'
import { DeclusterViewportIControl } from 'maplibre/decluster_viewport_control'
import { DestinationsMapLayers } from 'maplibre/destinations_map_layers'

const DEFAULT_ZOOM = 12
const MIN_CHARS = 3
const DEBOUNCE_MS = 300

function roundCoord (value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return value
  return Math.round(value * 1e6) / 1e6 // DB / API precision (see app/api/v01/destinations.rb)
}

/** Fixed-width string for form fields (matches persisted float rounding). */
function coordToDbInputString (value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return ''
  return roundCoord(value).toFixed(6)
}

/** Run fn after a slide-panel CSS transition, or immediately if none fires (e.g. reduced motion). */
function afterSlideTransition (el, fn) {
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

function getMaplibre () {
  return typeof window !== 'undefined' && window.maplibregl ? window.maplibregl : null
}

function createMarkerElement (label) {
  const el = document.createElement('div')
  el.className = 'destinations-marker'
  el.setAttribute('role', 'button')
  if (label) el.setAttribute('aria-label', label)

  const head = document.createElement('span')
  head.className = 'destinations-marker__head'

  const glint = document.createElement('span')
  glint.className = 'destinations-marker__glint'
  glint.setAttribute('aria-hidden', 'true')
  head.appendChild(glint)

  const pin = document.createElement('span')
  pin.className = 'destinations-marker__pin'
  pin.setAttribute('aria-hidden', 'true')

  el.appendChild(head)
  el.appendChild(pin)
  return el
}

// Split only before the next key:value token, not on spaces inside a value.
function splitFilterSegments (input) {
  return input.split(/\s+(?=[^\s:]+:)/).map((part) => part.trim()).filter(Boolean)
}

function parseKeyValueFilters (input) {
  if (!input || !input.includes(':')) return []
  const result = []
  splitFilterSegments(input).forEach((part) => {
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
    this._mapLayers = null
    this._domMarker = null
    this._domMarkerId = null
    this._domMarkerEl = null
    this._iconOverStack = []
    this._searchDebounce = null
    this._positionEdit = null
    this._onTurboFrameLoad = this._onTurboFrameLoad.bind(this)
    this._onDestroyConfirmed = (event) => this.destroyConfirmed(event)
    this._canDestroy = !!config.can_destroy
    this._formSidebarPlaceholder = config.form_sidebar_placeholder || ''
    this._mapGeojsonUrl = config.map_geojson_url || '/destinations/map.geojson'
    this._pendingHighlightId = null

    const maplibregl = getMaplibre()
    const mapEl = this.element.querySelector('#map')
    if (maplibregl && mapEl && config.map_layers) {
      this._initMap(maplibregl, mapEl, config, signal)
      const hid = config.highlight_destination_id
      if (hid != null && String(hid) !== '' && String(hid) !== '0') {
        this._pendingHighlightId = String(hid)
      }
    }

    this._initSearch(signal)
    this._initSelectionAndDestroy(signal)

    this._onPositionDragToggleDocumentClick = this._onPositionDragToggleDocumentClick.bind(this)
    this._onDestinationGeocoded = this._onDestinationGeocoded.bind(this)
    this._onDestinationVisitsChanged = this._onDestinationVisitsChanged.bind(this)
    this._onPositionDragResize = () => {
      if (this._positionEdit?.active) this._syncPositionDragCancelButtonPosition()
    }
    document.addEventListener('click', this._onPositionDragToggleDocumentClick, { signal })
    document.addEventListener('v2:destination-geocoded', this._onDestinationGeocoded, { signal })
    document.addEventListener('v2:destination-visits-changed', this._onDestinationVisitsChanged, { signal })
    window.addEventListener('resize', this._onPositionDragResize, { signal })

    document.addEventListener('turbo:before-cache', this._beforeCache, { signal })
    document.addEventListener('turbolinks:before-cache', this._beforeCache, { signal })
    document.addEventListener('turbo:frame-load', this._onTurboFrameLoad, { signal })
    this.element.addEventListener('confirm-click:confirmed', this._onDestroyConfirmed, { signal })
  }

  disconnect () {
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
    if (this._mapLayers) {
      this._mapLayers.disconnect()
      this._mapLayers = null
    }
    this._removeDomMarker()
    const mapEl = this.element.querySelector('#map')
    if (mapEl && mapEl._v2MaplibreMap) {
      try {
        mapEl._v2MaplibreMap.remove()
      } catch (e) { /* ignore */ }
      mapEl._v2MaplibreMap = null
    }
    this._iconOverStack = []
  }

  _removeDomMarker () {
    if (this._positionEdit && this._domMarkerId === this._positionEdit.markerId) {
      this._positionEdit.marker = null
    }
    if (this._domMarker) {
      try { this._domMarker.remove() } catch (e) { /* ignore */ }
    }
    this._domMarker = null
    this._domMarkerId = null
    this._domMarkerEl = null
  }

  _destinationRecord (idStr) {
    if (!this._mapLayers) return null
    return this._mapLayers.getDestination(idStr)
  }

  _syncHiddenGeojsonPins () {
    if (!this._mapLayers) return
    const hidden = []
    if (this._domMarkerId) hidden.push(this._domMarkerId)
    this._mapLayers.setHiddenDestinationIds(hidden)
  }

  _showDomMarker (idStr, { name = '', lngLat, active = true } = {}) {
    const maplibregl = getMaplibre()
    if (!maplibregl || !this._map || !lngLat) return

    if (this._domMarkerId === idStr && this._domMarker) {
      this._domMarker.setLngLat(lngLat)
      if (this._domMarkerEl) {
        this._domMarkerEl.classList.toggle('destinations-marker--active', active)
      }
      if (this._positionEdit && this._positionEdit.markerId === idStr) {
        this._positionEdit.marker = this._domMarker
      }
      this._syncHiddenGeojsonPins()
      return
    }

    this._removeDomMarker()
    const el = createMarkerElement(name)
    if (active) el.classList.add('destinations-marker--active')
    const marker = new maplibregl.Marker({ element: el, anchor: 'bottom' })
      .setLngLat(lngLat)
      .addTo(this._map)
    this._domMarker = marker
    this._domMarkerId = idStr
    this._domMarkerEl = el
    if (this._positionEdit && this._positionEdit.markerId === idStr) {
      this._positionEdit.marker = marker
    }
    this._syncHiddenGeojsonPins()
  }

  _clearDestinationHighlight () {
    if (!this.element) return
    this.element.querySelectorAll('tr.destination').forEach((tr) => tr.classList.remove('highlight', 'highlight--map-pin'))
    this._iconOverStack = []
    const keepMarker =
      this._positionEdit && this._domMarkerId === this._positionEdit.markerId
    if (!keepMarker) {
      this._removeDomMarker()
      this._syncHiddenGeojsonPins()
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
   * Padding for map.flyTo / fitBounds so the target is not hidden under overlay sidebars.
   */
  _mapFlyToPadding () {
    const inset = 48
    const gutter = 16
    const layoutRect = this.element.getBoundingClientRect()
    const padding = { top: inset, bottom: inset, left: inset, right: inset }

    const leftSidebar = this.element.querySelector('.destinations-sidebar')
    if (leftSidebar) {
      if (leftSidebar.classList.contains('slide-panel--collapsed')) {
        const expandBtn = this.element.querySelector('.destinations-sidebar-expand')
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

    const formSidebar = document.querySelector('.form-sidebar')
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

  /**
   * Highlight table row + map pin; optionally fly map to pin. Used for list clicks, marker clicks, and ?highlight_destination_id=.
   * @param {{ flyToMap?: boolean }} [options]
   */
  _focusDestinationInList (idStr, options = {}) {
    const flyToMap = !!options.flyToMap
    this._clearDestinationHighlight()
    let rec = this._destinationRecord(idStr)
    const rows = Array.from(this.element.querySelectorAll('tr.destination')).filter(
      (tr) => tr.getAttribute('data-destination-id') === idStr
    )
    const row = rows[0]
    if (!rec && row) {
      const lat = parseFloat(row.getAttribute('data-lat'))
      const lng = parseFloat(row.getAttribute('data-lng'))
      if (Number.isFinite(lat) && Number.isFinite(lng)) {
        rec = { lngLat: [lng, lat], name: '' }
      }
    }
    if (rec) {
      this._showDomMarker(idStr, { name: rec.name, lngLat: rec.lngLat, active: true })
      this._iconOverStack.push(idStr)
      if (flyToMap && this._map) {
        this._map.flyTo({
          center: rec.lngLat,
          zoom: Math.max(this._map.getZoom(), 14),
          padding: this._mapFlyToPadding(),
          duration: 500
        })
      }
    }
    if (rows.length) {
      rows.forEach((tr) => tr.classList.add('highlight'))
      this._scrollDestinationRowIntoView(row)
    }
  }

  _applyPendingHighlight () {
    if (!this._pendingHighlightId) return
    const idStr = this._pendingHighlightId
    if (!this._destinationRecord(idStr)) return
    this._focusDestinationInList(idStr, { flyToMap: true })
    this._pendingHighlightId = null
    this._stripHighlightParamFromUrl()
  }

  _buildMapGeojsonUrl (overrides = {}) {
    const base = this._mapGeojsonUrl || '/destinations/map.geojson'
    const url = new URL(base, window.location.origin)
    const form = this.element.querySelector('#destinations-search-form')
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

  _handleMapPointClick (feature) {
    const props = feature.properties || {}
    const idStr = String(props.id)
    const row = Array.from(this.element.querySelectorAll('tr.destination')).find((tr) => tr.getAttribute('data-destination-id') === idStr)
    if (row) {
      this._focusDestinationInList(idStr, { flyToMap: false })
      this._navigateFormSidebarToRowIfOpen(row, idStr)
      return
    }
    const destPage = Number(props.page)
    if (Number.isFinite(destPage) && destPage > 0) {
      const visitUrl = this._buildDestinationsIndexUrl({ page: destPage, highlight_destination_id: idStr })
      visit(visitUrl, { frame: 'destinations_list', action: 'advance' })
    } else {
      this._focusDestinationInList(idStr, { flyToMap: false })
    }
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
      const placeholder = params.geocoder_placeholder ||
        ((typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.search') : 'Search an address...')
      const emptyMsg = params.geocoder_empty ||
        ((typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.empty_result') : 'No results found')
      const tooltip = params.geocoder_tooltip ||
        ((typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.tooltip') : placeholder)
      const submitLabel = params.geocoder_submit ||
        ((typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.submit_search') : 'Search')
      map.addControl(new GeocoderIControl(placeholder, emptyMsg, { tooltip, submitLabel }), 'top-right')
    }

    const basesOnly = pickLayers(params.map_layers).bases
    const baseSpecs = basesOnly.length > 1
      ? basesOnly.map((b, i) => ({
        layerId: baseLayerIds[i],
        name: b.name,
        selected: !!(b.default || (!basesOnly.some((x) => x.default) && i === 0))
      }))
      : []
    if (baseSpecs.length > 0 || (overlayToggles && overlayToggles.length > 0)) {
      const layersTitle = params.map_layers_title || params.map_overlay_title || 'Layers'
      map.addControl(new OverlayLayersToggleIControl(overlayToggles || [], layersTitle, {
        bases: baseSpecs,
        baseSectionTitle: params.map_base_layers_title || '',
        overlaySectionTitle: params.map_overlay_title || ''
      }), 'top-right')
    }

    const highlightId = params.highlight_destination_id
    this._mapLayers = new DestinationsMapLayers(map, {
      buildUrl: (overrides) => {
        const merged = { ...overrides }
        if (highlightId != null && String(highlightId) !== '' && String(highlightId) !== '0') {
          merged.highlight_destination_id = String(highlightId)
        }
        return this._buildMapGeojsonUrl(merged)
      },
      onPointClick: (feature) => this._handleMapPointClick(feature),
      onFeaturesUpdated: () => this._applyPendingHighlight(),
      signal
    })
    this._mapLayers.connect()

    const tDecluster = (typeof I18n !== 'undefined' && I18n.t)
      ? I18n.t('destinations.index.map_decluster_viewport', { defaultValue: 'Déclusteriser la vue' })
      : 'Déclusteriser la vue'
    const tRecluster = (typeof I18n !== 'undefined' && I18n.t)
      ? I18n.t('destinations.index.map_recluster_viewport', { defaultValue: 'Clusteriser la vue' })
      : 'Clusteriser la vue'
    this._declusterControl = new DeclusterViewportIControl({
      getDeclustered: () => !!(this._mapLayers && this._mapLayers.isDeclusterViewportActive()),
      onToggle: (declustered) => {
        if (!this._mapLayers) return
        this._mapLayers.setDeclusterViewportActive(declustered)
      },
      titleDecluster: tDecluster,
      titleRecluster: tRecluster
    })
    map.addControl(this._declusterControl, 'top-right')

    const sidebar = this.element.querySelector('.destinations-sidebar')
    const scheduleResize = () => { afterSlideTransition(sidebar, () => map.resize()) }

    this.element.addEventListener('click', (e) => {
      const tr = e.target.closest && e.target.closest('tr.destination[data-destination-id]')
      if (tr) {
        if (e.target.closest && e.target.closest('input[type=checkbox], .destinations-row-delete, a[data-turbo-frame]')) return
        const id = tr.getAttribute('data-destination-id')
        if (!id) return
        // Any click on the list row: highlight + center map on pin (when coordinates exist).
        this._focusDestinationInList(id, { flyToMap: true })
        return
      }
      if (e.target.closest && e.target.closest('.destinations-sidebar-toggle')) {
        if (sidebar) sidebar.classList.add('slide-panel--collapsed')
        scheduleResize()
        return
      }
      if (e.target.closest && e.target.closest('.destinations-sidebar-expand')) {
        if (sidebar) sidebar.classList.remove('slide-panel--collapsed')
        scheduleResize()
        return
      }
      if (e.target.closest && e.target.closest('.destinations-position-drag-cancel')) {
        e.preventDefault()
        this._disablePositionDrag()
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
      const form = frame.querySelector('#destination-form-sidebar')
      if (!form) {
        this._onFormSidebarClosed()
        return
      }
      this._syncPositionEditFromFormSidebar(frame)
      if (this._positionEdit?.active) {
        requestAnimationFrame(() => this._syncPositionDragCancelButtonPosition())
      }
      return
    }
    if (frame.id === 'destinations_list' || frame.id === 'destinations_list_body') {
      requestAnimationFrame(() => {
        const url = new URL(window.location.href)
        const hid = url.searchParams.get('highlight_destination_id')
        if (hid) {
          this._normalizeDestinationsPageScroll()
          this._focusDestinationInList(String(hid), { flyToMap: false })
          const row = this.element.querySelector(`tr.destination[data-destination-id="${CSS.escape(String(hid))}"]`)
          if (row) this._navigateFormSidebarToRowIfOpen(row, String(hid))
          this._stripHighlightParamFromUrl()
        }
      })
      if (this._map) requestAnimationFrame(() => this._map.resize())
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
  _syncPositionFromMarker (destinationIdStr, marker) {
    if (!marker) return
    const ll = marker.getLngLat()
    let lat = typeof ll.lat === 'number' ? ll.lat : parseFloat(String(ll.lat))
    let lng = typeof ll.lng === 'number' ? ll.lng : parseFloat(String(ll.lng))
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return
    lat = roundCoord(lat)
    lng = roundCoord(lng)
    try {
      marker.setLngLat({ lng, lat })
    } catch (e) { /* ignore */ }
    if (this._mapLayers) this._mapLayers.updateDestinationCoords(destinationIdStr, lng, lat)
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

  _refreshPositionEditMarker () {
    const state = this._positionEdit
    if (!state) return
    if (this._domMarkerId === state.markerId && this._domMarker) {
      state.marker = this._domMarker
    }
  }

  /**
   * Horizontal center of the map band visible beside the open form sidebar (not full layout width).
   */
  _positionDragCancelButtonLeftPx () {
    const layout = this.element
    const layoutRect = layout.getBoundingClientRect()
    let visibleRight = layoutRect.right

    const formSidebar = document.querySelector('.form-sidebar')
    if (formSidebar && !formSidebar.classList.contains('slide-panel--collapsed')) {
      const formRect = formSidebar.getBoundingClientRect()
      if (formRect.left < visibleRight) visibleRight = formRect.left
    }

    const visibleLeft = layoutRect.left
    const centerX = visibleLeft + (visibleRight - visibleLeft) / 2
    return centerX - layoutRect.left
  }

  _syncPositionDragCancelButtonPosition () {
    const cancelBtn = this.element.querySelector('.destinations-position-drag-cancel')
    if (!cancelBtn || cancelBtn.classList.contains('d-none')) return
    cancelBtn.style.left = `${this._positionDragCancelButtonLeftPx()}px`
  }

  _setMapPositionDragCursor (active) {
    const canvas = this._map && typeof this._map.getCanvas === 'function' ? this._map.getCanvas() : null
    if (canvas) canvas.style.cursor = active ? 'crosshair' : ''
  }

  _syncPositionDragLayout (active) {
    const layout = this.element
    const sidebar = layout.querySelector('.destinations-sidebar')
    const cancelBtn = layout.querySelector('.destinations-position-drag-cancel')
    const state = this._positionEdit

    if (active) {
      layout.classList.add('destinations-map-layout--position-drag')
      if (sidebar && !sidebar.classList.contains('slide-panel--collapsed')) {
        sidebar.classList.add('slide-panel--collapsed')
        if (state) state.listSidebarHiddenForDrag = true
        afterSlideTransition(sidebar, () => {
          if (this._map) this._map.resize()
          this._syncPositionDragCancelButtonPosition()
        })
      } else if (state) {
        state.listSidebarHiddenForDrag = false
      }
      if (cancelBtn) cancelBtn.classList.remove('d-none')
      this._setMapPositionDragCursor(true)
      requestAnimationFrame(() => this._syncPositionDragCancelButtonPosition())
      return
    }

    layout.classList.remove('destinations-map-layout--position-drag')
    this._setMapPositionDragCursor(false)
    if (state?.listSidebarHiddenForDrag && sidebar) {
      sidebar.classList.remove('slide-panel--collapsed')
      state.listSidebarHiddenForDrag = false
      afterSlideTransition(sidebar, () => { if (this._map) this._map.resize() })
    }
    if (cancelBtn) {
      cancelBtn.classList.add('d-none')
      cancelBtn.style.left = ''
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
      const rec = this._domMarkerEl
      if (rec) rec.classList.remove('destinations-marker--dragging')
      state.active = false
    }
    if (state.dragEndHandler && state.marker) {
      try { state.marker.off('dragend', state.dragEndHandler) } catch (e) { /* ignore */ }
    }
    try {
      if (state.marker && typeof state.marker.setDraggable === 'function') state.marker.setDraggable(false)
    } catch (e) { /* ignore */ }
    if (state.toggleButton) this._applyPositionDragToggleUi(state.toggleButton, false)
    this._syncPositionDragLayout(false)
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
    if (this._domMarkerEl) this._domMarkerEl.classList.remove('destinations-marker--dragging')
    state.active = false
    this._syncPositionDragLayout(false)
    if (state.toggleButton) this._applyPositionDragToggleUi(state.toggleButton, false)
  }

  _enablePositionDrag () {
    const state = this._positionEdit
    if (!state || state.active || !this._map) return
    this._refreshPositionEditMarker()
    if (!state.marker || this._domMarkerId !== state.markerId) return
    state.mapClickHandler = (e) => {
      if (!this._positionEdit?.active) return
      const t = e.originalEvent && e.originalEvent.target
      if (t && typeof t.closest === 'function') {
        // Clicks on the HTML marker can still surface as map `click`; ignore (drag handles position).
        if (t.closest('.maplibregl-marker') || t.closest('.mapboxgl-marker') || t.closest('.destinations-marker')) return
        // MapLibre UI (zoom, geocoder, layer switcher…): do not move the pin.
        if (t.closest('.maplibregl-ctrl') || t.closest('.mapboxgl-ctrl')) return
      }
      if (!e.lngLat) return
      const mid = this._positionEdit.markerId
      const m = this._positionEdit.marker
      if (!m) return
      try {
        m.setLngLat(e.lngLat)
      } catch (err) { /* ignore */ }
      this._syncPositionFromMarker(mid, m)
    }
    this._map.on('click', state.mapClickHandler)
    try {
      state.marker.setDraggable(true)
    } catch (e) { /* ignore */ }
    if (this._domMarkerEl) this._domMarkerEl.classList.add('destinations-marker--dragging')
    state.active = true
    this._syncPositionDragLayout(true)
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
    if (!this._positionEdit) {
      const frame = document.getElementById('form_sidebar')
      if (frame) this._syncPositionEditFromFormSidebar(frame)
    }
    if (!this._positionEdit || btn.classList.contains('d-none')) return
    const fid = form.getAttribute('data-destination_id')
    if (fid == null || String(fid) !== String(this._positionEdit.markerId)) return
    this._refreshPositionEditMarker()
    e.preventDefault()
    e.stopPropagation()
    this._togglePositionDragMode(btn)
  }

  _forceResetPositionDragChrome () {
    const layout = this.element
    if (!layout.classList.contains('destinations-map-layout--position-drag')) return

    layout.classList.remove('destinations-map-layout--position-drag')
    this._setMapPositionDragCursor(false)
    const cancelBtn = layout.querySelector('.destinations-position-drag-cancel')
    if (cancelBtn) {
      cancelBtn.classList.add('d-none')
      cancelBtn.style.left = ''
    }
    const sidebar = layout.querySelector('.destinations-sidebar')
    if (sidebar) {
      sidebar.classList.remove('slide-panel--collapsed')
      afterSlideTransition(sidebar, () => { if (this._map) this._map.resize() })
    }
  }

  _onFormSidebarClosed () {
    this._teardownPositionEdit()
    this._forceResetPositionDragChrome()
    if (this._domMarker) {
      this._removeDomMarker()
      this._syncHiddenGeojsonPins()
    }
  }

  _onDestinationGeocoded (event) {
    if (!this._map) return
    const detail = event.detail || {}
    const destinationId = detail.destinationId != null ? String(detail.destinationId) : ''
    if (!destinationId || destinationId === '0') return

    const form = document.querySelector('#form_sidebar #destination-form-sidebar')
    const formId = form?.getAttribute('data-destination_id')
    if (!formId || String(formId) !== destinationId) return

    const lat = typeof detail.lat === 'number' ? detail.lat : parseFloat(String(detail.lat))
    const lng = typeof detail.lng === 'number' ? detail.lng : parseFloat(String(detail.lng))
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      if (this._domMarkerId === destinationId) {
        this._removeDomMarker()
        this._syncHiddenGeojsonPins()
      }
      return
    }

    if (this._mapLayers) this._mapLayers.updateDestinationCoords(destinationId, lng, lat)
    this._showDomMarker(destinationId, { name: detail.name || '', lngLat: [lng, lat], active: true })

    try {
      const zoom = Math.max(this._map.getZoom(), 16)
      this._map.flyTo({ center: [lng, lat], zoom, padding: this._mapFlyToPadding() })
    } catch (e) { /* ignore */ }
  }

  _onDestinationVisitsChanged (event) {
    const destinationId = event.detail?.destinationId
    if (!destinationId) return

    const overrides = { highlight_destination_id: String(destinationId) }
    const currentPage = new URL(window.location.href).searchParams.get('page')
    if (currentPage) overrides.page = currentPage
    visit(this._buildDestinationsIndexUrl(overrides), { frame: 'destinations_list', action: 'advance' })
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
    let rec = this._destinationRecord(id)
    if (!rec) {
      const latInp = form.querySelector('#destination_lat')
      const lngInp = form.querySelector('#destination_lng')
      const lat = latInp ? parseFloat(latInp.value) : NaN
      const lng = lngInp ? parseFloat(lngInp.value) : NaN
      if (Number.isFinite(lat) && Number.isFinite(lng)) {
        const nameInp = form.querySelector('#destination_name')
        rec = { lngLat: [lng, lat], name: nameInp ? nameInp.value : '' }
      }
    }

    if (rec) this._showDomMarker(id, { name: rec.name, lngLat: rec.lngLat, active: true })

    const marker = this._domMarker
    if (toggleButton) {
      if (!marker || typeof marker.setDraggable !== 'function') {
        toggleButton.classList.add('d-none')
        this._applyPositionDragToggleUi(toggleButton, false)
        return
      }
      toggleButton.classList.remove('d-none')
      this._applyPositionDragToggleUi(toggleButton, false)
    }
    if (!marker || typeof marker.setDraggable !== 'function') return

    const dragEndHandler = () => {
      this._syncPositionFromMarker(id, marker)
    }

    marker.on('dragend', dragEndHandler)
    this._positionEdit = {
      markerId: id,
      marker,
      dragEndHandler,
      toggleButton: toggleButton || null,
      active: false,
      mapClickHandler: null,
      listSidebarHiddenForDrag: false
    }
  }

  _initSelectionAndDestroy (signal) {
    this.element.addEventListener('click', (e) => {
      if (e.target.closest && e.target.closest('.destinations-toggle-selection')) {
        e.preventDefault()
        this._toggleRowSelection()
        return
      }
      if (e.target.closest && e.target.closest('.destinations-bulk-delete, .destinations-row-delete')) {
        return
      }
      if (e.target.closest && e.target.closest('#destination_box input[type=checkbox][name^="destinations"]')) {
        e.stopPropagation()
      }
    }, { signal })
  }

  _toggleRowSelection () {
    const box = this.element.querySelector('#destination_box')
    if (!box) return
    box.querySelectorAll('tbody tr.destination input[type=checkbox]').forEach((cb) => {
      cb.checked = !cb.checked
    })
  }

  _selectedDestinationIds () {
    const box = this.element.querySelector('#destination_box')
    if (!box) return []
    return Array.from(box.querySelectorAll('tbody tr.destination input[type=checkbox]:checked'))
      .map((cb) => {
        const row = cb.closest('tr.destination')
        return row && row.getAttribute('data-destination-id')
      })
      .filter(Boolean)
  }

  destroyConfirmed (event) {
    if (!this._canDestroy) return

    const button = event.detail?.element
    if (!button) return

    if (button.classList.contains('destinations-row-delete')) {
      const id = button.getAttribute('data-destination-id')
      if (id) this._destroyDestinations([id])
      return
    }

    if (button.classList.contains('destinations-bulk-delete')) {
      const ids = this._selectedDestinationIds()
      if (ids.length) this._destroyDestinations(ids)
    }
  }

  async _destroyDestinations (ids) {
    if (!this._canDestroy || !ids || !ids.length) return

    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    const headers = {
      Accept: 'application/json',
      'X-CSRF-Token': token || ''
    }
    const uniqueIds = [...new Set(ids.map((id) => String(id)))]

    try {
      let res
      if (uniqueIds.length === 1) {
        res = await fetch(`/api/0.1/destinations/${encodeURIComponent(uniqueIds[0])}.json`, {
          method: 'DELETE',
          headers,
          credentials: 'same-origin'
        })
      } else {
        const url = `/api/0.1/destinations.json?ids=${encodeURIComponent(uniqueIds.join(','))}`
        res = await fetch(url, { method: 'DELETE', headers, credentials: 'same-origin' })
      }

      if (res.status === 204 || res.ok) {
        uniqueIds.forEach((id) => {
          this._removeDestinationMarker(id)
          this._clearFormSidebarIfDestination(id)
        })
        visit(this._buildDestinationsIndexUrl(), { frame: 'destinations_list', action: 'advance' })
        return
      }

      const text = await res.text().catch(() => '')
      window.alert(text || `HTTP ${res.status}`)
    } catch (e) {
      window.alert(e && e.message ? e.message : String(e))
    }
  }

  _removeDestinationMarker (idStr) {
    if (this._domMarkerId === String(idStr)) this._removeDomMarker()
    if (this._mapLayers) this._mapLayers.removeDestination(idStr)
    if (this._iconOverStack) {
      this._iconOverStack = this._iconOverStack.filter((id) => id !== String(idStr))
    }
  }

  _clearFormSidebarIfDestination (idStr) {
    const form = document.querySelector('#form_sidebar #destination-form-sidebar')
    if (!form || String(form.getAttribute('data-destination_id')) !== String(idStr)) return
    const frame = document.getElementById('form_sidebar')
    if (!frame) return
    frame.replaceChildren()
    const p = document.createElement('p')
    p.className = 'form-sidebar-placeholder text-muted small mb-0'
    p.textContent = this._formSidebarPlaceholder
    frame.appendChild(p)
    this._teardownPositionEdit()
  }

  _initSearch (signal) {
    const form = this.element.querySelector('#destinations-search-form')
    const input = this.element.querySelector('#search-query')
    const wrapper = this.element.querySelector('.destinations-search-wrapper')
    let badges = this.element.querySelector('#search-filters-badges')
    if (!form || !input) return

    const ensureBadgesHost = () => {
      if (badges) return badges
      if (!wrapper) return null
      badges = document.createElement('div')
      badges.id = 'search-filters-badges'
      badges.className = 'mt-1'
      wrapper.appendChild(badges)
      return badges
    }

    const draftFilterValue = () => {
      const key = (input.dataset.filterKeyDraft || '').trim()
      const value = input.value.trim()
      if (!key || !value) return null
      return `${key}:${value}`
    }

    const hasCommittedFilter = (raw) => Array.from(form.querySelectorAll('input[name="filters[]"]')).some((field) => field.value === raw)

    const addCommittedFilter = (raw) => {
      if (!raw || hasCommittedFilter(raw)) return

      const field = document.createElement('input')
      field.type = 'hidden'
      field.name = 'filters[]'
      field.value = raw
      form.appendChild(field)

      const host = ensureBadgesHost()
      if (!host) return
      const badge = document.createElement('span')
      badge.className = 'badge bg-primary me-1 mb-1 search-filter-badge'
      badge.dataset.filter = raw
      badge.append(document.createTextNode(raw))

      const removeBtn = document.createElement('button')
      removeBtn.type = 'button'
      removeBtn.className = 'ms-1 text-white search-filter-badge-remove'
      removeBtn.dataset.removeFilter = raw
      removeBtn.setAttribute('aria-label', `Remove filter ${raw}`)
      const icon = document.createElement('i')
      icon.className = 'fa fa-times'
      removeBtn.appendChild(icon)
      badge.appendChild(removeBtn)
      host.appendChild(badge)
    }

    const removeCommittedFilter = (raw) => {
      Array.from(form.querySelectorAll('input[name="filters[]"]')).forEach((field) => {
        if (field.value === raw) field.remove()
      })
      if (badges) {
        badges.querySelectorAll('.search-filter-badge').forEach((badge) => {
          if (badge.dataset.filter === raw) badge.remove()
        })
      }
    }

    const submitForm = (additionalFilters = []) => {
      if (additionalFilters.length) {
        additionalFilters.forEach((raw) => addCommittedFilter(raw))
        input.value = ''
        input.dataset.filterKeyDraft = ''
        if (wrapper) wrapper.dispatchEvent(new CustomEvent('filtered-search:clear-draft'))
      }
      const url = this._buildDestinationsIndexUrl()
      visit(url, { frame: 'destinations_list', action: 'advance' })
      this._clearDestinationHighlight()
      if (this._mapLayers) this._mapLayers.reload({ fitBounds: true })
      if (this._declusterControl) this._declusterControl.syncUi()
    }

    input.addEventListener('input', () => {
      clearTimeout(this._searchDebounce)
      this._searchDebounce = setTimeout(() => {
        this._searchDebounce = null
      }, DEBOUNCE_MS)
    }, { signal })

    input.addEventListener('keydown', (e) => {
      if (e.key !== 'Enter') return
      e.preventDefault()
      const draftFilter = draftFilterValue()
      if (draftFilter) {
        submitForm([draftFilter])
        return
      }
      const val = input.value.trim()
      const filters = parseKeyValueFilters(val)
      if (filters.length) {
        submitForm(filters.map((f) => f.raw))
        return
      }
      if (hasMinCharsForSearch(val)) submitForm([val])
    }, { signal })

    const badgesHost = ensureBadgesHost()
    if (badgesHost) {
      badgesHost.addEventListener('click', (e) => {
        const removeBtn = e.target.closest('[data-remove-filter]')
        if (!removeBtn) return
        e.preventDefault()
        const raw = removeBtn.getAttribute('data-remove-filter')
        if (!raw) return
        removeCommittedFilter(raw)
        const url = this._buildDestinationsIndexUrl({ page: 1 })
        visit(url, { frame: 'destinations_list', action: 'advance' })
        this._clearDestinationHighlight()
        if (this._mapLayers) this._mapLayers.reload({ fitBounds: true })
        if (this._declusterControl) this._declusterControl.syncUi()
      }, { signal })
    }
  }
}
