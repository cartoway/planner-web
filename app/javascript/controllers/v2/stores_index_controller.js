// Copyright © Cartoway
// V2 stores index: same map interactions as destinations (HTML markers via Teritorio
// clusters, flyTo padding, layer switch, position drag). Features come from page JSON.

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

const positionEdit = createPositionEditBindings({
  latId: 'store_lat',
  lngId: 'store_lng',
  nameId: 'store_name',
  formSidebarId: 'store-form-sidebar',
  formIdAttr: 'data-store_id',
  rowSelector: (id) => `.store-row[data-store-id="${CSS.escape(String(id))}"]`,
  collapseSidebar: (host, onDone) => host._collapseListSidebar(onDone)
})

const { afterSlideTransition } = positionEdit


function storesToFeatures (stores) {
  return (stores || []).flatMap((store) => {
    const lat = parseFloat(store.lat)
    const lng = parseFloat(store.lng)
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return []
    return [{
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [lng, lat] },
      properties: { id: store.id, name: store.name || '' }
    }]
  })
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
    this._config = config
    this._map = null
    this._mapLayers = null
    this._domMarker = null
    this._domMarkerId = null
    this._domMarkerEl = null
    this._activeStoreId = null
    this._positionEdit = null
    this._pendingHighlightId = null
    this._indexUrl = config.index_url || '/stores'
    this._onTurboFrameLoad = this._onTurboFrameLoad.bind(this)
    this._onPositionDragToggleDocumentClick = this._onPositionDragToggleDocumentClick.bind(this)
    this._onRecordGeocoded = this._onRecordGeocoded.bind(this)
    this._onPositionDragResize = () => {
      if (this._positionEdit?.active) this._syncPositionDragCancelButtonPosition()
    }

    const maplibregl = getMaplibre()
    const mapEl = this.element.querySelector('#map')
    if (maplibregl && mapEl && config.map_layers) {
      this._initMap(maplibregl, mapEl, config, signal)
      const hid = config.highlight_store_id
      if (hid != null && String(hid) !== '' && String(hid) !== '0') {
        this._pendingHighlightId = String(hid)
      }
    }

    document.addEventListener('click', this._onPositionDragToggleDocumentClick, { signal })
    document.addEventListener('v2:record-geocoded', this._onRecordGeocoded, { signal })
    window.addEventListener('resize', this._onPositionDragResize, { signal })
    bindTurboMapHost({
      signal,
      teardown: () => this._teardownMap(),
      getContainer: () => this.element.querySelector('#map')
    })
    document.addEventListener('turbo:frame-load', this._onTurboFrameLoad, { signal })
    document.addEventListener('turbo:before-stream-render', this._onBeforeStreamRender, { signal })
    // Sync map pins after chunked table-filter finishes (not on each keystroke).
    this.element.addEventListener('v2--table-filter:filtered', () => {
      this._syncHiddenGeojsonPins()
    }, { signal })
  }

  _onBeforeStreamRender = (event) => {
    const stream = event.detail?.newStream
    if (!stream || stream.getAttribute('action') !== 'remove') return
    const target = stream.getAttribute('target') || ''
    const match = target.match(/^store_(\d+)$/)
    if (!match) return
    const storeId = match[1]
    const render = event.detail.render
    event.detail.render = async (streamElement) => {
      await render(streamElement)
      this._removeStoreAfterDestroy(storeId)
    }
  }

  _removeStoreAfterDestroy (storeId) {
    if (this._mapLayers) this._mapLayers.removeDestination(String(storeId))
    if (this._domMarkerId === String(storeId)) this._removeDomMarker()
    const form = document.querySelector('#form_sidebar #store-form-sidebar')
    if (form && String(form.getAttribute('data-store_id')) === String(storeId)) {
      const frame = document.getElementById('form_sidebar')
      const tpl = document.getElementById('form-sidebar-placeholder-template')
      if (frame && tpl?.content) {
        frame.removeAttribute('src')
        frame.innerHTML = ''
        frame.appendChild(tpl.content.cloneNode(true))
      }
    }
  }

  disconnect () {
    if (this._abort) this._abort.abort()
    this._abort = null
    this._teardownMap()
    this._map = null
  }

  _teardownMap () {
    this._teardownPositionEdit()
    this._clearStoreHighlight()
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

  _storeRecord (idStr) {
    if (!this._mapLayers) return null
    return this._mapLayers.getDestination(idStr)
  }

  _syncHiddenGeojsonPins () {
    if (!this._mapLayers) return
    const hidden = []
    if (this._domMarkerId) hidden.push(this._domMarkerId)
    this.element.querySelectorAll('.store-row.d-none').forEach((row) => {
      const id = row.getAttribute('data-store-id')
      if (id) hidden.push(id)
    })
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

  _paintActiveStore () {
    const root = this.element?.querySelector('#map') || this.element
    paintActiveDisc(root, this._activeStoreId)
  }

  _isActiveStoreFeature (feature) {
    return isFeatureActive(this._activeStoreId, feature)
  }

  _clearStoreHighlight () {
    if (!this.element) return
    this.element.querySelectorAll('.store-row').forEach((tr) => tr.classList.remove('highlight', 'highlight--map-pin'))
    this._activeStoreId = null
    this._paintActiveStore()
    if (!shouldKeepDomMarkerOnClear(this._positionEdit, this._domMarkerId)) {
      this._removeDomMarker()
      this._syncHiddenGeojsonPins()
    }
  }

  _collapseListSidebar (onCollapsed) {
    const sidebar = this.element.querySelector('.destinations-sidebar')
    if (!sidebar || sidebar.classList.contains('slide-panel--collapsed')) return false
    sidebar.classList.add('slide-panel--collapsed')
    afterSlideTransition(sidebar, () => {
      if (this._map) this._map.resize()
      if (onCollapsed) onCollapsed()
    })
    return true
  }

  _expandListSidebar () {
    const sidebar = this.element.querySelector('.destinations-sidebar')
    if (!sidebar || !sidebar.classList.contains('slide-panel--collapsed')) return false
    sidebar.classList.remove('slide-panel--collapsed')
    afterSlideTransition(sidebar, () => { if (this._map) this._map.resize() })
    return true
  }

  _scrollStoreRowIntoView (row) {
    const box = this.element && this.element.querySelector('#store_box')
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
   * @param {{ flyToMap?: boolean, revealMobileMap?: boolean }} [options]
   *   revealMobileMap: on mobile, switch Liste → Carte before flyTo (fa-expand only).
   */
  _focusStoreInList (idStr, options = {}) {
    const flyToMap = !!options.flyToMap
    const revealMobileMap = !!options.revealMobileMap
    this._clearStoreHighlight()
    let rec = this._storeRecord(idStr)
    const rows = Array.from(this.element.querySelectorAll('.store-row')).filter(
      (tr) => tr.getAttribute('data-store-id') === idStr
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
    this._activeStoreId = String(idStr)
    this._paintActiveStore()

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
          map.once('moveend', () => this._paintActiveStore())
        })
      }
      if (revealMobileMap) this._withMobileMapVisible(runFly)
      else runFly()
    }
    if (rows.length) {
      rows.forEach((tr) => tr.classList.add('highlight'))
      this._scrollStoreRowIntoView(row)
    }
  }

  _applyPendingHighlight () {
    if (!this._pendingHighlightId) return
    const idStr = this._pendingHighlightId
    if (!this._storeRecord(idStr) && !this.element.querySelector(`.store-row[data-store-id="${CSS.escape(idStr)}"]`)) return
    this._focusStoreInList(idStr, { flyToMap: true })
    this._pendingHighlightId = null
    this._stripHighlightParamFromUrl()
  }

  _stripHighlightParamFromUrl () {
    const url = new URL(window.location.href)
    if (!url.searchParams.has('highlight_store_id')) return
    url.searchParams.delete('highlight_store_id')
    window.history.replaceState(window.history.state || {}, '', url.toString())
  }

  _isStoreFormSidebarOpen () {
    const frame = document.getElementById('form_sidebar')
    return !!(frame && frame.querySelector('#store-form-sidebar'))
  }

  _navigateFormSidebarToRowIfOpen (row, idStr) {
    if (!row || !this._isStoreFormSidebarOpen()) return
    const form = document.querySelector('#form_sidebar #store-form-sidebar')
    const currentId = form && form.getAttribute('data-store_id')
    if (currentId != null && String(currentId) === String(idStr)) return
    const link = row.querySelector('a[data-turbo-frame="form_sidebar"]')
    const href = link && link.getAttribute('href')
    if (!href) return
    visit(href, { frame: 'form_sidebar', track: false })
  }

  _handleMapPointClick (feature) {
    const props = feature.properties || {}
    const idStr = String(props.id)
    const row = Array.from(this.element.querySelectorAll('.store-row')).find((tr) => tr.getAttribute('data-store-id') === idStr)
    this._focusStoreInList(idStr, { flyToMap: false })
    if (row) this._navigateFormSidebarToRowIfOpen(row, idStr)
  }

  _initMap (maplibregl, container, params, signal) {
    this._teardownPositionEdit()

    const resolved = resolveMapStyle(params.map_layers)
    const { style, baseLayerIds, overlayToggles } = resolved
    const fromHash = parseMapViewHash()
    const map = attachMapToContainer(container, {
      style,
      center: fromHash ? fromHash.center : [parseFloat(params.map_lng) || 0, parseFloat(params.map_lat) || 0],
      zoom: fromHash ? fromHash.zoom : (params.map_zoom != null ? Number(params.map_zoom) : DEFAULT_ZOOM),
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
      map.addControl(new GeocoderIControl(
        params.geocoder_placeholder || 'Search',
        params.geocoder_empty || 'No results',
        { tooltip: params.geocoder_tooltip, submitLabel: params.geocoder_submit }
      ), 'top-right')
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
        onBaseChange: useStyleSwitch ? (spec) => this._switchBaseLayer(spec) : null
      }), 'top-right')
    }

    this._mapLayersOptions = {
      staticFeatures: storesToFeatures(params.stores),
      onPointClick: (feature) => this._handleMapPointClick(feature),
      onFeaturesUpdated: () => {
        this._applyPendingHighlight()
        this._paintActiveStore()
      },
      isFeatureActive: (feature) => this._isActiveStoreFeature(feature),
      getMovePadding: () => this._mapFlyToPadding(),
      signal
    }
    this._mapLayers = new DestinationsMapLayers(map, this._mapLayersOptions)
    this._mapLayers.connect({ refitBounds: !fromHash })

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
      const tr = e.target.closest && e.target.closest('.store-row[data-store-id]')
      if (tr) {
        if (e.target.closest && e.target.closest('input[type=checkbox], a[data-turbo-frame], a[data-turbo-method], button.btn-danger')) return
        if (e.target.closest && e.target.closest('.stores-row-center:disabled')) return
        const id = tr.getAttribute('data-store-id')
        if (!id) return
        const centerBtn = e.target.closest && e.target.closest('.stores-row-center')
        this._focusStoreInList(id, { flyToMap: true, revealMobileMap: !!centerBtn })
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
    const sidebarFrame = document.getElementById('form_sidebar')
    if (sidebarFrame) this._syncPositionEditFromFormSidebar(sidebarFrame)
  }

  _switchBaseLayer (spec) {
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
      if (switchId !== this._baseSwitchId || !this._map || !this._mapLayersOptions) return
      if (this._mapLayers) return
      applyOverlays(
        this._map,
        this._mapOverlayLayers || [],
        this._overlayVisibility,
        this._overlayToggles,
        { includeRaster: true, beforeId: CLUSTER_LAYER_ID }
      ).catch(() => { /* overlay style fetch failed */ })
      this._mapLayers = new DestinationsMapLayers(this._map, this._mapLayersOptions)
      this._mapLayers.connect({ refitBounds: false, force: true })
      if (this._declusterControl) this._declusterControl.syncUi?.()
      const sidebarFrame = document.getElementById('form_sidebar')
      if (sidebarFrame) this._syncPositionEditFromFormSidebar(sidebarFrame)
    }
    this._map.once('style.load', reattach)
    this._map.setStyle(nextStyle, { diff: false })
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
    if (!frame || frame.id !== 'form_sidebar') return
    const form = frame.querySelector('#store-form-sidebar')
    if (!form) {
      const savedMarker = frame.querySelector('[data-v2-saved-id]')
      const savedId = savedMarker?.getAttribute('data-v2-saved-id')
      // Keep map coords after a successful save; otherwise restore like cancel placement.
      this._onFormSidebarClosed({ discardMapChanges: !savedId })
      if (savedId) {
        this._expandListSidebar()
        const url = new URL(this._indexUrl, window.location.origin)
        url.searchParams.set('highlight_store_id', String(savedId))
        visit(url.toString(), { frame: 'main' })
      }
      return
    }
    this._syncPositionEditFromFormSidebar(frame)
    if (this._positionEdit?.active) {
      requestAnimationFrame(() => this._syncPositionDragCancelButtonPosition())
    }
  }

  _syncPositionFromMarker (storeIdStr, marker) {
    positionEdit.syncPositionFromMarker(this, storeIdStr, marker)
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
      clearActiveId: () => { this._activeStoreId = null },
      paint: () => this._paintActiveStore()
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
   *   Skip after a successful save — navigation/reload applies the new coords.
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

  _onRecordGeocoded (event) {
    if (!this._map) return
    const detail = event.detail || {}
    if (detail.resourcePrefix !== 'store') return
    const storeId = detail.id != null ? String(detail.id) : ''
    if (!storeId) return
    const form = document.querySelector('#form_sidebar #store-form-sidebar')
    const formId = form?.getAttribute('data-store_id')
    if (!formId || String(formId) !== storeId) return
    const lat = typeof detail.lat === 'number' ? detail.lat : parseFloat(String(detail.lat))
    const lng = typeof detail.lng === 'number' ? detail.lng : parseFloat(String(detail.lng))
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      if (this._domMarkerId === storeId) {
        this._removeDomMarker()
        this._syncHiddenGeojsonPins()
      }
      return
    }
    this._collapseListSidebar()
    if (this._mapLayers) this._mapLayers.updateDestinationCoords(storeId, lng, lat)
    this._showDomMarker(storeId, { name: detail.name || '', lngLat: [lng, lat], active: true })
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

  _syncPositionEditFromFormSidebar (frameEl) {
    // Switching store forms discards unsaved map moves on the previous one.
    this._abandonPositionEditSession()
    if (!this._map || !frameEl) return
    const form = frameEl.querySelector('#store-form-sidebar')
    if (!form || form.getAttribute('data-position-editable') !== 'true') return
    const rawId = form.getAttribute('data-store_id')
    const id = rawId != null ? String(rawId) : ''
    // "0" = new store (same as destinations); still allow map click placement.
    if (!id) return
    const toggleButton = form.querySelector('[data-v2-map-position-drag-toggle]')
    let rec = this._storeRecord(id)
    if (!rec) {
      const latInp = form.querySelector('#store_lat')
      const lngInp = form.querySelector('#store_lng')
      const lat = latInp ? parseFloat(latInp.value) : NaN
      const lng = lngInp ? parseFloat(lngInp.value) : NaN
      if (Number.isFinite(lat) && Number.isFinite(lng)) {
        const nameInp = form.querySelector('#store_name')
        rec = { lngLat: [lng, lat], name: nameInp ? nameInp.value : '' }
      }
    }
    const baselineLngLat = rec
      ? parseLngLat(rec.lngLat[0], rec.lngLat[1])
      : parseLngLat(
        form.querySelector('#store_lng')?.value,
        form.querySelector('#store_lat')?.value
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
    this._activeStoreId = id
    this._paintActiveStore()

    if (toggleButton) {
      toggleButton.classList.remove('d-none')
      this._applyPositionDragToggleUi(toggleButton, false)
    }
  }
}
