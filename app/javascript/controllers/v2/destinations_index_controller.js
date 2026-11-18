// Copyright © Cartoway
// V2 destinations index: MapLibre map (global from layout) + key:value search debounce.
// Vanilla DOM APIs only — no jQuery.

import { Controller } from '@hotwired/stimulus'
import { visit } from 'turbo/frame_promoted_visit'
import { pickLayers, resolveMapStyle, styleForBaseLayer, basesNeedStyleSwitch, applyOverlays } from 'maplibre/raster_layers'
import { GeocoderIControl } from 'maplibre/geocoder_control'
import { OverlayLayersToggleIControl } from 'maplibre/overlay_layers_toggle_control'
import { DeclusterViewportIControl } from 'maplibre/decluster_viewport_control'
import { DestinationsMapLayers, CLUSTER_LAYER_ID } from 'maplibre/destinations_map_layers'
import { createDestinationMarkerElement } from 'maplibre/destination_markers'
import { isFeatureActive, paintActiveDisc, parseLngLat, shouldKeepDomMarkerOnClear } from 'maplibre/map_index_selection'
import { createPositionEditBindings } from 'maplibre/index_position_edit'
import { disableMapPitchAndRotation } from 'maplibre/map_interactions'
import { attachMapToContainer, bindTurboMapHost, detachMapFromContainer, getMaplibre } from 'maplibre/turbo_map_host'
import { bindMapViewHash, parseMapViewHash } from 'lib/map_view_hash'
import {
  applyMobileMapPane,
  isMapIndexMobileLayout,
  mapIndexFlyToPadding
} from 'lib/map_index_mobile'

const DEFAULT_ZOOM = 12
const MIN_CHARS = 3
const DEBOUNCE_MS = 300

const positionEdit = createPositionEditBindings({
  latId: 'destination_lat',
  lngId: 'destination_lng',
  nameId: 'destination_name',
  formSidebarId: 'destination-form-sidebar',
  formIdAttr: 'data-destination_id',
  rowSelector: (id) => `.destination[data-destination-id="${CSS.escape(String(id))}"]`,
  collapseSidebar: (host, onDone) => host._collapseDestinationsSidebar(onDone)
})

const { afterSlideTransition } = positionEdit

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
  static targets = ['layout', 'mobilePane']

  setMobilePane (event) {
    const pane = event.currentTarget.dataset.pane
    if (!pane) return
    this._applyMobilePane(pane)
  }

  _applyMobilePane (pane) {
    const layout = this.hasLayoutTarget ? this.layoutTarget : this.element
    layout.classList.toggle('is-mobile-pane-list', pane === 'list')
    layout.classList.toggle('is-mobile-pane-map', pane === 'map')
    this.mobilePaneTargets.forEach((button) => {
      const active = button.dataset.pane === pane
      button.classList.toggle('btn-primary', active)
      button.classList.toggle('btn-outline-secondary', !active)
      button.setAttribute('aria-selected', active ? 'true' : 'false')
    })
    requestAnimationFrame(() => { if (this._map) this._map.resize() })
  }

  /** On mobile list pane, switch to Carte then run fn after map.resize. */
  _withMobileMapVisible (fn) {
    if (!isMapIndexMobileLayout(this.element)) {
      fn()
      return
    }
    const layout = this.hasLayoutTarget ? this.layoutTarget : this.element
    const switched = applyMobileMapPane(layout, this.mobilePaneTargets)
    if (!switched) {
      fn()
      return
    }
    requestAnimationFrame(() => {
      if (this._map) this._map.resize()
      requestAnimationFrame(fn)
    })
  }

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
    this._activeDestinationId = null
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
    bindTurboMapHost({
      signal,
      teardown: () => this._teardownMap(),
      getContainer: () => this.element.querySelector('#map')
    })
    document.addEventListener('turbo:frame-load', this._onTurboFrameLoad, { signal })
    this.element.addEventListener('confirm-click:confirmed', this._onDestroyConfirmed, { signal })
  }

  disconnect () {
    if (this._abort) this._abort.abort()
    this._abort = null
    this._teardownMap()
    this._map = null
  }

  _teardownMap () {
    this._teardownPositionEdit()
    this._clearDestinationHighlight()
    if (this._unbindMapViewHash) {
      this._unbindMapViewHash()
      this._unbindMapViewHash = null
    }
    if (this._mapLayers) {
      this._mapLayers.disconnect()
      this._mapLayers = null
    }
    this._removeDomMarker()
    detachMapFromContainer(this.element.querySelector('#map'))
    this._map = null
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
        // No element id: Teritorio discs own feature ids; duplicate ids made conceal() hit this pin.
        this._domMarkerEl.classList.add('destinations-marker--dom-pin')
        this._domMarkerEl.classList.toggle('destinations-marker--active', active)
      }
      this._bindPositionEditMarker(this._domMarker)
      this._syncHiddenGeojsonPins()
      return
    }

    this._removeDomMarker()
    const el = createDestinationMarkerElement(name)
    // Mark as edit pin (no id) so paintActiveDisc / conceal only touch Teritorio discs.
    el.classList.add('destinations-marker--dom-pin')
    if (active) el.classList.add('destinations-marker--active')
    const marker = new maplibregl.Marker({ element: el, anchor: 'center' })
      .setLngLat(lngLat)
      .addTo(this._map)
    this._domMarker = marker
    this._domMarkerId = idStr
    this._domMarkerEl = el
    this._bindPositionEditMarker(marker)
    this._syncHiddenGeojsonPins()
  }

  _bindPositionEditMarker (marker) {
    const state = this._positionEdit
    if (!state || !marker || this._domMarkerId !== state.markerId) return
    if (state.marker !== marker) {
      if (state.dragEndHandler && typeof marker.on === 'function') marker.on('dragend', state.dragEndHandler)
      state.marker = marker
    }
    if (!state.active || typeof marker.setDraggable !== 'function') return
    try { marker.setDraggable(true) } catch (e) { /* ignore */ }
    if (this._domMarkerEl) this._domMarkerEl.classList.add('destinations-marker--dragging')
  }

  _paintActiveDestination () {
    const root = this.element?.querySelector('#map') || this.element
    paintActiveDisc(root, this._activeDestinationId)
  }

  _isActiveDestinationFeature (feature) {
    return isFeatureActive(this._activeDestinationId, feature)
  }

  _clearDestinationHighlight () {
    if (!this.element) return
    this.element.querySelectorAll('.destination').forEach((tr) => tr.classList.remove('highlight', 'highlight--map-pin'))
    this._iconOverStack = []
    this._activeDestinationId = null
    this._paintActiveDestination()
    if (!shouldKeepDomMarkerOnClear(this._positionEdit, this._domMarkerId)) {
      this._removeDomMarker()
      this._syncHiddenGeojsonPins()
    }
  }

  _collapseDestinationsSidebar (onCollapsed) {
    const sidebar = this.element.querySelector('.destinations-sidebar')
    if (!sidebar || sidebar.classList.contains('slide-panel--collapsed')) return false
    sidebar.classList.add('slide-panel--collapsed')
    afterSlideTransition(sidebar, () => {
      if (this._map) this._map.resize()
      if (onCollapsed) onCollapsed()
    })
    return true
  }

  _expandDestinationsSidebar () {
    const sidebar = this.element.querySelector('.destinations-sidebar')
    if (!sidebar || !sidebar.classList.contains('slide-panel--collapsed')) return false
    sidebar.classList.remove('slide-panel--collapsed')
    afterSlideTransition(sidebar, () => { if (this._map) this._map.resize() })
    return true
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
   * Mobile map pane: full-bleed (no left list / menu padding).
   */
  _mapFlyToPadding () {
    return mapIndexFlyToPadding({
      layoutEl: this.element,
      leftSidebar: this.element.querySelector('.destinations-sidebar'),
      expandBtn: this.element.querySelector('.destinations-sidebar-expand'),
      formSidebar: document.querySelector('.form-sidebar'),
      mobile: isMapIndexMobileLayout(this.element)
    })
  }

  /**
   * Highlight table row + map pin; optionally fly map to pin. Used for list clicks, marker clicks, and ?highlight_destination_id=.
   * @param {{ flyToMap?: boolean, revealMobileMap?: boolean }} [options]
   *   revealMobileMap: on mobile, switch Liste → Carte before flyTo (fa-expand only).
   */
  _focusDestinationInList (idStr, options = {}) {
    const flyToMap = !!options.flyToMap
    const revealMobileMap = !!options.revealMobileMap
    this._clearDestinationHighlight()
    let rec = this._destinationRecord(idStr)
    const rows = Array.from(this.element.querySelectorAll('.destination')).filter(
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

    // Selection paints the Teritorio disc (customers-style). DOM pin is for position edit only.
    this._activeDestinationId = String(idStr)
    this._paintActiveDestination()

    if (rec && flyToMap && this._map) {
      const map = this._map
      const center = rec.lngLat
      const zoom = Math.max(map.getZoom(), 14)
      const runFly = () => {
        if (this._map !== map) return
        const padding = this._mapFlyToPadding()
        requestAnimationFrame(() => {
          if (this._map !== map) return
          map.flyTo({ center, zoom, padding, duration: 500 })
          // Teritorio rebuilds markers after move; re-apply active class.
          map.once('moveend', () => this._paintActiveDestination())
        })
      }
      // Card click centers behind the list; only fa-expand reveals the map pane.
      if (revealMobileMap) this._withMobileMapVisible(runFly)
      else runFly()
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
    const row = Array.from(this.element.querySelectorAll('.destination')).find((tr) => tr.getAttribute('data-destination-id') === idStr)
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
    visit(href, { frame: 'form_sidebar', track: false })
  }

  _initMap (maplibregl, container, params, signal) {
    this._teardownPositionEdit()

    const resolved = resolveMapStyle(params.map_layers)
    const { style, baseLayerIds, overlayToggles } = resolved
    const fromHash = parseMapViewHash()
    const centerLng = fromHash ? fromHash.center[0] : (parseFloat(params.map_lng) || 0)
    const centerLat = fromHash ? fromHash.center[1] : (parseFloat(params.map_lat) || 0)
    const zoom = fromHash ? fromHash.zoom : (params.map_zoom != null ? Number(params.map_zoom) : DEFAULT_ZOOM)

    const map = attachMapToContainer(container, {
      style,
      center: [centerLng, centerLat],
      zoom,
      attributionControl: true,
      dragRotate: false,
      pitchWithRotate: false,
      touchPitch: false,
      maxPitch: 0,
      minPitch: 0,
      pitch: 0,
      bearing: 0
    })
    if (!map) return
    disableMapPitchAndRotation(map)
    map.on('style.load', () => disableMapPitchAndRotation(map))
    this._map = map
    this._unbindMapViewHash = bindMapViewHash(map)

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

    const { bases: basesOnly, overlays: overlayLayers } = pickLayers(params.map_layers)
    this._mapOverlayLayers = overlayLayers
    this._overlayToggles = overlayToggles || []
    this._overlayVisibility = {}
    this._overlayToggles.forEach((t) => {
      this._overlayVisibility[t.layerId] = !!t.initialVisible
    })
    const useStyleSwitch = resolved.mode === 'vector' || basesNeedStyleSwitch(basesOnly)
    const baseSpecs = basesOnly.length > 1
      ? basesOnly.map((b, i) => ({
        layerId: baseLayerIds[i],
        name: b.name,
        key: b.key,
        url: b.url,
        vectorStyleUrl: b.vectorStyleUrl,
        attribution: b.attribution,
        selected: !!(b.default || (!basesOnly.some((x) => x.default) && i === 0))
      }))
      : []
    if (baseSpecs.length > 0 || this._overlayToggles.length > 0) {
      const layersTitle = params.map_layers_title || params.map_overlay_title || 'Layers'
      map.addControl(new OverlayLayersToggleIControl(this._overlayToggles, layersTitle, {
        bases: baseSpecs,
        baseSectionTitle: params.map_base_layers_title || '',
        overlaySectionTitle: params.map_overlay_title || '',
        onBaseChange: useStyleSwitch
          ? (spec) => this._switchDestinationsBaseLayer(spec)
          : null
      }), 'top-right')
    }

    const highlightId = params.highlight_destination_id
    this._destinationsMapLayersOptions = {
      buildUrl: (overrides) => {
        const merged = { ...overrides }
        if (highlightId != null && String(highlightId) !== '' && String(highlightId) !== '0') {
          merged.highlight_destination_id = String(highlightId)
        }
        return this._buildMapGeojsonUrl(merged)
      },
      onPointClick: (feature) => this._handleMapPointClick(feature),
      onFeaturesUpdated: () => {
        this._applyPendingHighlight()
        this._paintActiveDestination()
      },
      isFeatureActive: (feature) => this._isActiveDestinationFeature(feature),
      getMovePadding: () => this._mapFlyToPadding(),
      signal
    }
    this._mapLayers = new DestinationsMapLayers(map, this._destinationsMapLayersOptions)
    this._mapLayers.connect({ refitBounds: !fromHash })

    // Vector base: merge all overlays after style load.
    // Raster base: raster overlays are already in the composite style; only merge vector_style_url overlays.
    if (overlayLayers.length && (resolved.mode === 'vector' || overlayLayers.some((o) => o.vectorStyleUrl))) {
      const runOverlays = () => {
        this._syncOverlayVisibilityFromControl()
        applyOverlays(
          map,
          overlayLayers,
          this._overlayVisibility,
          this._overlayToggles,
          { includeRaster: resolved.mode === 'vector', beforeId: CLUSTER_LAYER_ID }
        ).catch(() => { /* overlay style fetch failed */ })
      }
      if (map.isStyleLoaded()) runOverlays()
      else map.once('load', runOverlays)
    }

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
      const tr = e.target.closest && e.target.closest('.destination[data-destination-id]')
      if (tr) {
        if (e.target.closest && e.target.closest('input[type=checkbox], .destinations-row-delete, a[data-turbo-frame]')) return
        if (e.target.closest && e.target.closest('.destinations-row-center:disabled')) return
        const id = tr.getAttribute('data-destination-id')
        if (!id) return
        const centerBtn = e.target.closest && e.target.closest('.destinations-row-center')
        // Card click: center map behind the list. fa-expand: also switch to Carte on mobile.
        this._focusDestinationInList(id, { flyToMap: true, revealMobileMap: !!centerBtn })
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
        this._cancelPositionDrag()
      }
    }, { signal })

    map.once('load', () => { map.resize() })

    // Sidebar form may already be open (e.g. reload); enable draggable pin when applicable.
    const sidebarFrame = document.getElementById('form_sidebar')
    if (sidebarFrame) this._syncPositionEditFromFormSidebar(sidebarFrame)
  }

  _switchDestinationsBaseLayer (spec) {
    if (!this._map || !spec) return
    const nextStyle = styleForBaseLayer(spec)
    if (!nextStyle) return

    this._syncOverlayVisibilityFromControl()

    if (this._mapLayers) {
      this._mapLayers.disconnect()
      this._mapLayers = null
    }
    this._teardownPositionEdit()
    this._removeDomMarker()

    const switchId = (this._baseSwitchId = (this._baseSwitchId || 0) + 1)
    const reattach = () => {
      if (switchId !== this._baseSwitchId || !this._map || !this._destinationsMapLayersOptions) return
      if (this._mapLayers) return
      // After setStyle the map is empty of overlays — re-merge all (vector_style_url preferred).
      applyOverlays(
        this._map,
        this._mapOverlayLayers || [],
        this._overlayVisibility,
        this._overlayToggles,
        { includeRaster: true, beforeId: CLUSTER_LAYER_ID }
      ).catch(() => { /* overlay style fetch failed */ })
      this._mapLayers = new DestinationsMapLayers(this._map, this._destinationsMapLayersOptions)
      // Keep current camera; fitBounds on reconnect fights setStyle and can drop the viewport fetch.
      this._mapLayers.connect({ refitBounds: false, force: true })
      if (this._declusterControl) this._declusterControl.syncUi?.()
      const sidebarFrame = document.getElementById('form_sidebar')
      if (sidebarFrame) this._syncPositionEditFromFormSidebar(sidebarFrame)
    }

    // Register BEFORE setStyle: inline raster styles can emit style.load synchronously.
    this._map.once('style.load', reattach)
    this._map.setStyle(nextStyle, { diff: false })
    // Fallbacks if style.load was missed or the style is already usable.
    requestAnimationFrame(() => {
      if (this._map && this._map.isStyleLoaded()) reattach()
    })
    this._map.once('idle', reattach)
  }

  _syncOverlayVisibilityFromControl () {
    if (!this._overlayVisibility) this._overlayVisibility = {}
    const root = this.element.querySelector('.maplibre-overlay-toggles')
    if (!root) return
    root.querySelectorAll('input[type="checkbox"][id^="maplibre-layer-overlay-"]').forEach((cb) => {
      const idx = cb.id.replace('maplibre-layer-overlay-', '')
      if (idx === '' || Number.isNaN(Number(idx))) return
      this._overlayVisibility[`overlay-${idx}`] = !!cb.checked
    })
  }

  _onTurboFrameLoad (event) {
    const frame = event.target
    if (!frame || !frame.id) return
    if (frame.id === 'form_sidebar') {
      const form = frame.querySelector('#destination-form-sidebar')
      if (!form) {
        const savedMarker = frame.querySelector('[data-destinations-saved-id]')
        const savedId = savedMarker?.getAttribute('data-destinations-saved-id')
        if (savedMarker) savedMarker.removeAttribute('data-destinations-saved-id')
        // Keep map coords after a successful save; otherwise restore like cancel placement.
        this._onFormSidebarClosed({ discardMapChanges: !savedId })
        if (savedId) {
          this._expandDestinationsSidebar()
          this._refreshListAfterSidebarSave(String(savedId))
        }
        return
      }
      this._syncPositionEditFromFormSidebar(frame)
      if (this._positionEdit?.active) {
        requestAnimationFrame(() => this._syncPositionDragCancelButtonPosition())
      }
      return
    }
    if (frame.id === 'destinations_list' || frame.id === 'destinations_list_body') {
      this._syncPerPageFromListFrame()
      this._syncCountFromListFrame()
      requestAnimationFrame(() => {
        const url = new URL(window.location.href)
        const hid = url.searchParams.get('highlight_destination_id')
        if (hid) {
          this._normalizeDestinationsPageScroll()
          this._focusDestinationInList(String(hid), { flyToMap: false })
          const row = this.element.querySelector(`.destination[data-destination-id="${CSS.escape(String(hid))}"]`)
          if (row) this._navigateFormSidebarToRowIfOpen(row, String(hid))
          this._stripHighlightParamFromUrl()
        }
      })
      if (this._map) requestAnimationFrame(() => this._map.resize())
    }
  }

  _syncPerPageFromListFrame () {
    const frame = document.getElementById('destinations_list')
    const form = this.element.querySelector('#destinations-search-form')
    const perInput = form && form.querySelector('input[name="per_page"]')
    if (!frame || !perInput) return

    const activeOption = frame.querySelector('.destinations-per-page-option.active')
    const fromOption = activeOption && activeOption.getAttribute('data-per-page')
    const fromFrame = frame.getAttribute('data-per-page')
    const fromUrl = new URL(window.location.href).searchParams.get('per_page')
    const next = (fromOption || fromFrame || fromUrl || '').toString().trim()
    if (next) perInput.value = next
  }

  // Counts live in the sidebar title row (outside turbo-frame#destinations_list).
  // Turbo FrameRenderer only swaps frame children, so read counts from the inner meta node
  // (updated on each list refresh), not from the frame's stale data-* attributes.
  _syncCountFromListFrame () {
    const frame = document.getElementById('destinations_list')
    if (!frame) return

    const meta = frame.querySelector('[data-destinations-list-counts]')
    this._syncCountBlock('#count', {
      shown: meta?.getAttribute('data-shown-count') ?? frame.getAttribute('data-shown-count'),
      total: meta?.getAttribute('data-total-count') ?? frame.getAttribute('data-total-count'),
      label: meta?.getAttribute('data-count-label')
    })
    this._syncCountBlock('#count-visits', {
      shown: meta?.getAttribute('data-page-visits-count'),
      total: meta?.getAttribute('data-total-visits-count'),
      label: meta?.getAttribute('data-visits-count-label')
    })
  }

  _syncCountBlock (rootSelector, { shown, total, label }) {
    const root = this.element.querySelector(rootSelector)
    if (!root) return
    const numbers = root.querySelector('.destinations-list-count-numbers')
    if (numbers && shown != null && total != null) numbers.textContent = `${shown} / ${total}`
    const labelEl = root.querySelector('.destinations-toolbar-label')
    if (labelEl && label != null) labelEl.textContent = label
  }

  _refreshListAfterSidebarSave (destinationId) {
    const overrides = { highlight_destination_id: destinationId }
    const currentPage = new URL(window.location.href).searchParams.get('page')
    if (currentPage) overrides.page = currentPage
    visit(this._buildDestinationsIndexUrl(overrides), { frame: 'destinations_list' })
    if (this._mapLayers) this._mapLayers.reload({ fitBounds: false })
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

  _syncPositionFromMarker (destinationIdStr, marker) {
    positionEdit.syncPositionFromMarker(this, destinationIdStr, marker)
  }

  _refreshPositionEditMarker () {
    positionEdit.refreshPositionEditMarker(this)
  }

  _syncPositionDragCancelButtonPosition () {
    positionEdit.syncPositionDragCancelButtonPosition(this)
  }

  _setMapPositionDragCursor (active) {
    positionEdit.setMapPositionDragCursor(this, active)
  }

  _syncPositionDragLayout (active) {
    positionEdit.syncPositionDragLayout(this, active)
  }

  _teardownPositionEdit () {
    positionEdit.teardownPositionEdit(this)
  }

  _readEditLngLat () {
    return positionEdit.readEditLngLat(this._domMarker)
  }

  _applyEditLngLat (lngLat) {
    positionEdit.applyEditLngLat(this, lngLat)
  }

  /** Restore GeoJSON + list row coords (form fields may already be gone on sidebar close). */
  _restoreMapCoordsOnly (idStr, lngLat) {
    positionEdit.restoreMapCoordsOnly(this, idStr, lngLat)
  }

  /** Discard unsaved map moves for the open edit session (form-open baseline). */
  _abandonPositionEditSession () {
    positionEdit.abandonSession(this, {
      clearActiveId: () => { this._activeDestinationId = null },
      paint: () => this._paintActiveDestination()
    })
  }

  _cancelPositionDrag () {
    positionEdit.cancelPositionDrag(this)
  }

  _disablePositionDrag () {
    positionEdit.disablePositionDrag(this)
  }

  _enablePositionDrag () {
    positionEdit.enablePositionDrag(this)
  }

  _applyPlacementClick (lngLat) {
    positionEdit.applyPlacementClick(this, lngLat)
  }

  _togglePositionDragMode (btn) {
    positionEdit.togglePositionDragMode(this, btn)
  }

  _applyPositionDragToggleUi (btn, active) {
    positionEdit.applyPositionDragToggleUi(btn, active)
  }

  _onPositionDragToggleDocumentClick (e) {
    positionEdit.onPositionDragToggleDocumentClick(this, e, {
      syncFromFormSidebar: (frame) => this._syncPositionEditFromFormSidebar(frame)
    })
  }

  _forceResetPositionDragChrome () {
    positionEdit.forceResetPositionDragChrome(this)
  }

  /**
   * @param {{ discardMapChanges?: boolean }} [options]
   *   discardMapChanges: restore marker/GeoJSON to form-open baseline (same idea as cancel placement).
   *   Skip after a successful save — list/map reload applies the new coords.
   */
  _onFormSidebarClosed (options = {}) {
    const discardMapChanges = options.discardMapChanges !== false
    if (discardMapChanges) this._abandonPositionEditSession()
    else this._teardownPositionEdit()
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
    if (!destinationId) return

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

    this._collapseDestinationsSidebar()

    if (this._mapLayers) this._mapLayers.updateDestinationCoords(destinationId, lng, lat)
    this._showDomMarker(destinationId, { name: detail.name || '', lngLat: [lng, lat], active: true })

    try {
      const map = this._map
      const zoom = Math.max(map.getZoom(), 16)
      const padding = this._mapFlyToPadding()
      requestAnimationFrame(() => {
        if (this._map !== map) return
        map.flyTo({ center: [lng, lat], zoom, padding })
      })
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
    // Switching destination forms discards unsaved map moves on the previous one.
    this._abandonPositionEditSession()
    if (!this._map || !frameEl) return

    const form = frameEl.querySelector('#destination-form-sidebar')
    if (!form || form.getAttribute('data-position-editable') !== 'true') return

    const rawId = form.getAttribute('data-destination_id')
    const id = rawId != null ? String(rawId) : ''
    if (!id) return

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

    const baselineLngLat = rec
      ? parseLngLat(rec.lngLat[0], rec.lngLat[1])
      : parseLngLat(
        form.querySelector('#destination_lng')?.value,
        form.querySelector('#destination_lat')?.value
      )

    const dragEndHandler = () => {
      const current = this._positionEdit
      this._syncPositionFromMarker(id, current && current.marker)
    }
    this._positionEdit = {
      markerId: id,
      marker: null,
      dragEndHandler,
      toggleButton: toggleButton || null,
      active: false,
      mapClickHandler: null,
      listSidebarHiddenForDrag: false,
      baselineLngLat,
      initialLngLat: null
    }

    if (rec) this._showDomMarker(id, { name: rec.name, lngLat: rec.lngLat, active: true })

    // Align list↔map selection with the open form so the previous disc drops --active.
    this._activeDestinationId = id
    this._paintActiveDestination()

    if (toggleButton) {
      toggleButton.classList.remove('d-none')
      this._applyPositionDragToggleUi(toggleButton, false)
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
    box.querySelectorAll('.destination[data-destination-id] input[type=checkbox]').forEach((cb) => {
      cb.checked = !cb.checked
    })
  }

  _selectedDestinationIds () {
    const box = this.element.querySelector('#destination_box')
    if (!box) return []
    return Array.from(box.querySelectorAll('.destination[data-destination-id] input[type=checkbox]:checked'))
      .map((cb) => {
        const row = cb.closest('.destination[data-destination-id]')
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
      if (!id) return
      event.detail.handled = true
      this._destroyDestinations([id], button)
      return
    }

    if (button.classList.contains('destinations-bulk-delete')) {
      const ids = this._selectedDestinationIds()
      if (!ids.length) return
      event.detail.handled = true
      this._destroyDestinations(ids, button)
    }
  }

  async _destroyDestinations (ids, button) {
    if (!this._canDestroy || !ids || !ids.length) return

    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    const headers = {
      Accept: 'application/json',
      'X-CSRF-Token': token || ''
    }
    const uniqueIds = [...new Set(ids.map((id) => String(id)))]
    // Prefer confirm-click's pre-arm HTML (trash), not the armed check label.
    const confirmClick = button &&
      this.application.getControllerForElementAndIdentifier(button, 'confirm-click')
    const originalHtml = confirmClick?.originalHtml ?? button?.innerHTML ?? null
    if (button) {
      button.disabled = true
      // Keep button label on the spinner when present (same rules as confirm-click).
      button.innerHTML = confirmClick?.spinnerHtml?.() ||
        '<i class="fa fa-spinner fa-spin fa-fw" aria-hidden="true"></i>'
    }

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
      if (button && originalHtml != null) {
        button.disabled = false
        button.innerHTML = originalHtml
      }
    } catch (e) {
      window.alert(e && e.message ? e.message : String(e))
      if (button && originalHtml != null) {
        button.disabled = false
        button.innerHTML = originalHtml
      }
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
