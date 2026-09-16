// Copyright © Cartoway
// V2 stores index: same map interactions as destinations (GeoJSON circles, HTML pin on
// focus, flyTo padding, layer switch, position drag). Features come from page JSON.

import { Controller } from '@hotwired/stimulus'
import { visit } from 'turbo/frame_promoted_visit'
import { navigator as turboNavigator } from '@hotwired/turbo'
import { pickLayers, resolveMapStyle, styleForBaseLayer, basesNeedStyleSwitch, applyOverlays } from 'maplibre/raster_layers'
import { GeocoderIControl } from 'maplibre/geocoder_control'
import { OverlayLayersToggleIControl } from 'maplibre/overlay_layers_toggle_control'
import { DeclusterViewportIControl } from 'maplibre/decluster_viewport_control'
import { DestinationsMapLayers, CLUSTER_LAYER_ID } from 'maplibre/destinations_map_layers'
import { disableMapPitchAndRotation } from 'maplibre/map_interactions'

const DEFAULT_ZOOM = 12

function roundCoord (value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return value
  return Math.round(value * 1e6) / 1e6
}

function coordToDbInputString (value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return ''
  return roundCoord(value).toFixed(6)
}

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
    document.addEventListener('turbo:before-cache', this._beforeCache, { signal })
    document.addEventListener('turbolinks:before-cache', this._beforeCache, { signal })
    document.addEventListener('turbo:frame-load', this._onTurboFrameLoad, { signal })
    this.element.addEventListener('input', (e) => {
      if (e.target && e.target.closest && e.target.closest('[data-v2--table-filter-target="input"]')) {
        requestAnimationFrame(() => this._syncHiddenGeojsonPins())
      }
    }, { signal })
  }

  disconnect () {
    if (this._abort) this._abort.abort()
    this._abort = null
    this._teardownMap()
    this._map = null
  }

  _beforeCache = () => {
    const visitState = turboNavigator.currentVisit
    if (visitState && visitState.willRender === false) return
    this._teardownMap()
  }

  _teardownMap () {
    this._teardownPositionEdit()
    this._clearStoreHighlight()
    if (this._mapLayers) {
      this._mapLayers.disconnect()
      this._mapLayers = null
    }
    this._removeDomMarker()
    const mapEl = this.element.querySelector('#map')
    if (mapEl && mapEl._v2MaplibreMap) {
      try { mapEl._v2MaplibreMap.remove() } catch (e) { /* ignore */ }
      mapEl._v2MaplibreMap = null
    }
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
    this.element.querySelectorAll('tr.store-row.d-none').forEach((row) => {
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
      if (this._domMarkerEl) this._domMarkerEl.classList.toggle('destinations-marker--active', active)
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

  _clearStoreHighlight () {
    if (!this.element) return
    this.element.querySelectorAll('tr.store-row').forEach((tr) => tr.classList.remove('highlight', 'highlight--map-pin'))
    const keepMarker = this._positionEdit && this._domMarkerId === this._positionEdit.markerId
    if (!keepMarker) {
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
          padding.left = Math.max(inset, Math.ceil(expandRect.right - layoutRect.left) + gutter)
        }
      } else {
        const sidebarRect = leftSidebar.getBoundingClientRect()
        if (sidebarRect.width > 0) padding.left = Math.ceil(sidebarRect.width) + gutter
      }
    }
    const formSidebar = document.querySelector('.form-sidebar')
    if (formSidebar && !formSidebar.classList.contains('slide-panel--collapsed')) {
      const formRect = formSidebar.getBoundingClientRect()
      if (formRect.width > 0) {
        padding.right = Math.max(inset, Math.ceil(layoutRect.right - formRect.left) + gutter)
      }
    }
    return padding
  }

  _focusStoreInList (idStr, options = {}) {
    const flyToMap = !!options.flyToMap
    this._clearStoreHighlight()
    let rec = this._storeRecord(idStr)
    const rows = Array.from(this.element.querySelectorAll('tr.store-row')).filter(
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
    if (rec) {
      this._showDomMarker(idStr, { name: rec.name, lngLat: rec.lngLat, active: true })
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
      this._scrollStoreRowIntoView(row)
    }
  }

  _applyPendingHighlight () {
    if (!this._pendingHighlightId) return
    const idStr = this._pendingHighlightId
    if (!this._storeRecord(idStr) && !this.element.querySelector(`tr.store-row[data-store-id="${CSS.escape(idStr)}"]`)) return
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
    visit(href, { frame: 'form_sidebar' })
  }

  _handleMapPointClick (feature) {
    const props = feature.properties || {}
    const idStr = String(props.id)
    const row = Array.from(this.element.querySelectorAll('tr.store-row')).find((tr) => tr.getAttribute('data-store-id') === idStr)
    this._focusStoreInList(idStr, { flyToMap: false })
    if (row) this._navigateFormSidebarToRowIfOpen(row, idStr)
  }

  _initMap (maplibregl, container, params, signal) {
    this._teardownPositionEdit()
    if (container._v2MaplibreMap) {
      try { container._v2MaplibreMap.remove() } catch (e) { /* ignore */ }
      container._v2MaplibreMap = null
    }

    const resolved = resolveMapStyle(params.map_layers)
    const { style, baseLayerIds, overlayToggles } = resolved
    const map = new maplibregl.Map({
      container,
      style,
      center: [parseFloat(params.map_lng) || 0, parseFloat(params.map_lat) || 0],
      zoom: params.map_zoom != null ? Number(params.map_zoom) : DEFAULT_ZOOM,
      attributionControl: true,
      dragRotate: false,
      pitchWithRotate: false,
      touchPitch: false,
      maxPitch: 0,
      minPitch: 0,
      pitch: 0,
      bearing: 0
    })
    disableMapPitchAndRotation(map)
    map.on('style.load', () => disableMapPitchAndRotation(map))
    container._v2MaplibreMap = map
    this._map = map

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
      onFeaturesUpdated: () => this._applyPendingHighlight(),
      getMovePadding: () => this._mapFlyToPadding(),
      signal
    }
    this._mapLayers = new DestinationsMapLayers(map, this._mapLayersOptions)
    this._mapLayers.connect()

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
      const tr = e.target.closest && e.target.closest('tr.store-row[data-store-id]')
      if (tr) {
        if (e.target.closest && e.target.closest('input[type=checkbox], a[data-turbo-frame], a[data-turbo-method], button.btn-danger')) return
        if (e.target.closest && e.target.closest('.stores-row-center:disabled')) return
        const id = tr.getAttribute('data-store-id')
        if (!id) return
        this._focusStoreInList(id, { flyToMap: true })
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
      this._onFormSidebarClosed()
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
    if (!marker) return
    const ll = marker.getLngLat()
    let lat = typeof ll.lat === 'number' ? ll.lat : parseFloat(String(ll.lat))
    let lng = typeof ll.lng === 'number' ? ll.lng : parseFloat(String(ll.lng))
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return
    lat = roundCoord(lat)
    lng = roundCoord(lng)
    try { marker.setLngLat({ lng, lat }) } catch (e) { /* ignore */ }
    if (this._mapLayers) this._mapLayers.updateDestinationCoords(storeIdStr, lng, lat)
    const latInp = document.getElementById('store_lat')
    const lngInp = document.getElementById('store_lng')
    const sync = (input, valueStr) => {
      if (!input) return
      input.value = valueStr
      input.dispatchEvent(new Event('input', { bubbles: true }))
      input.dispatchEvent(new Event('change', { bubbles: true }))
    }
    sync(latInp, coordToDbInputString(lat))
    sync(lngInp, coordToDbInputString(lng))
    const row = this.element.querySelector(`tr.store-row[data-store-id="${storeIdStr}"]`)
    if (row) {
      row.setAttribute('data-lat', coordToDbInputString(lat))
      row.setAttribute('data-lng', coordToDbInputString(lng))
    }
  }

  _refreshPositionEditMarker () {
    const state = this._positionEdit
    if (!state) return
    if (this._domMarkerId === state.markerId && this._domMarker) state.marker = this._domMarker
  }

  _positionDragCancelButtonLeftPx () {
    const layout = this.element
    const layoutRect = layout.getBoundingClientRect()
    let visibleRight = layoutRect.right
    const formSidebar = document.querySelector('.form-sidebar')
    if (formSidebar && !formSidebar.classList.contains('slide-panel--collapsed')) {
      const formRect = formSidebar.getBoundingClientRect()
      if (formRect.left < visibleRight) visibleRight = formRect.left
    }
    return layoutRect.left + (visibleRight - layoutRect.left) / 2 - layoutRect.left
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
      const collapsed = this._collapseListSidebar(() => this._syncPositionDragCancelButtonPosition())
      if (state) state.listSidebarHiddenForDrag = collapsed
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
      if (this._domMarkerEl) this._domMarkerEl.classList.remove('destinations-marker--dragging')
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
        if (t.closest('.maplibregl-marker') || t.closest('.mapboxgl-marker') || t.closest('.destinations-marker')) return
        if (t.closest('.maplibregl-ctrl') || t.closest('.mapboxgl-ctrl')) return
      }
      if (!e.lngLat) return
      const mid = this._positionEdit.markerId
      const m = this._positionEdit.marker
      if (!m) return
      try { m.setLngLat(e.lngLat) } catch (err) { /* ignore */ }
      this._syncPositionFromMarker(mid, m)
    }
    this._map.on('click', state.mapClickHandler)
    try { state.marker.setDraggable(true) } catch (e) { /* ignore */ }
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
    if (icon) icon.className = active ? 'fa fa-times fa-fw' : 'fa fa-location-crosshairs fa-fw'
  }

  _onPositionDragToggleDocumentClick (e) {
    const btn = e.target.closest('[data-v2-map-position-drag-toggle]')
    if (!btn) return
    const form = document.getElementById('store-form-sidebar')
    if (!form || !form.contains(btn)) return
    if (!this._positionEdit) {
      const frame = document.getElementById('form_sidebar')
      if (frame) this._syncPositionEditFromFormSidebar(frame)
    }
    if (!this._positionEdit || btn.classList.contains('d-none')) return
    const fid = form.getAttribute('data-store_id')
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

  _onRecordGeocoded (event) {
    if (!this._map) return
    const detail = event.detail || {}
    if (detail.resourcePrefix !== 'store') return
    const storeId = detail.id != null ? String(detail.id) : ''
    if (!storeId || storeId === '0') return
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
      this._map.flyTo({ center: [lng, lat], zoom: Math.max(this._map.getZoom(), 16), padding: this._mapFlyToPadding() })
    } catch (e) { /* ignore */ }
  }

  _syncPositionEditFromFormSidebar (frameEl) {
    this._teardownPositionEdit()
    if (!this._map || !frameEl) return
    const form = frameEl.querySelector('#store-form-sidebar')
    if (!form || form.getAttribute('data-position-editable') !== 'true') return
    const rawId = form.getAttribute('data-store_id')
    const id = rawId != null ? String(rawId) : ''
    if (!id || id === '0') return
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
    const dragEndHandler = () => { this._syncPositionFromMarker(id, marker) }
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
}
