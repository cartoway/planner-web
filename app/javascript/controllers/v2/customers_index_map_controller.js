// Copyright © Cartoway
// Customers index: Teritorio clusters + Liste/Carte panes (same chrome as destinations/stores).
import { Controller } from "@hotwired/stimulus"
import { visit } from "turbo/frame_promoted_visit"
import { attachMapToContainer, detachMapFromContainer, getMaplibre, scheduleMapResize, bindTurboMapHost } from "maplibre/turbo_map_host"
import { pickLayers, resolveMapStyle, styleForBaseLayer, basesNeedStyleSwitch, applyOverlays } from "maplibre/raster_layers"
import { OverlayLayersToggleIControl } from "maplibre/overlay_layers_toggle_control"
import { DeclusterViewportIControl } from "maplibre/decluster_viewport_control"
import { DestinationsMapLayers, CLUSTER_LAYER_ID } from "maplibre/destinations_map_layers"
import { isFeatureActive, paintActiveDisc } from "maplibre/map_index_selection"
import { disableMapPitchAndRotation } from "maplibre/map_interactions"
import { bindMapViewHash, parseMapViewHash } from "lib/map_view_hash"
import {
  applyMobileMapPane,
  isMapIndexMobileLayout,
  mapIndexFlyToPadding
} from "lib/map_index_mobile"


function afterSlideTransition (el, fn) {
  if (!el) {
    fn()
    return
  }
  let settled = false
  const finish = () => {
    if (settled) return
    settled = true
    el.removeEventListener("transitionend", onEnd)
    clearTimeout(fallbackId)
    fn()
  }
  const onEnd = (e) => {
    if (e.target !== el || e.propertyName !== "transform") return
    finish()
  }
  el.addEventListener("transitionend", onEnd)
  const fallbackId = setTimeout(finish, 500)
}

function customersToFeatures (customers) {
  return (customers || []).flatMap((customer) => {
    const lat = parseFloat(customer.lat)
    const lng = parseFloat(customer.lng)
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return []
    const status = customer.test ? "test" : (customer.isActiv ? "active" : "inactive")
    const page = Number(customer.page)
    return [{
      type: "Feature",
      id: customer.id,
      geometry: { type: "Point", coordinates: [lng, lat] },
      properties: {
        id: customer.id,
        name: customer.name || "",
        vehicles: customer.max_vehicles || 0,
        status,
        page: Number.isFinite(page) && page > 0 ? page : 1
      }
    }]
  })
}


export default class extends Controller {
  static targets = ["layout", "map", "mobilePane", "legend"]

  connect () {
    this._abort = new AbortController()
    const { signal } = this._abort
    this._activeCustomerId = null
    this._mapLayers = null
    this._onResize = () => this._syncLegendPosition()

    this._onTurboFrameLoad = this._onTurboFrameLoad.bind(this)
    this._onUrlFilterChange = () => { this._syncMapFeaturesWithUrlFilter() }
    this._bindSidebarChrome()
    window.addEventListener("resize", this._onResize, { signal })
    window.addEventListener("popstate", this._onUrlFilterChange, { signal })
    document.addEventListener("turbo:frame-load", this._onTurboFrameLoad, { signal })
    document.addEventListener("turbo:load", this._onUrlFilterChange, { signal })

    const maplibregl = getMaplibre()
    if (maplibregl && this.hasMapTarget) {
      this._initMap(maplibregl, this.mapTarget, this.parseConfig(), signal)
    }

    bindTurboMapHost({
      signal,
      teardown: () => this._teardownMap(),
      getContainer: () => this.hasMapTarget ? this.mapTarget : null
    })

    requestAnimationFrame(() => {
      this._syncLegendPosition()
      this._applyHighlightFromUrl()
    })
  }


  disconnect () {
    this._abort?.abort()
    if (this._unbindMapViewHash) this._unbindMapViewHash()
    this._teardownMap()
  }

  setMobilePane (event) {
    const pane = event.currentTarget.dataset.pane
    if (!pane) return
    this._applyMobilePane(pane)
  }

  _applyMobilePane (pane) {
    const layout = this.hasLayoutTarget ? this.layoutTarget : this.element
    layout.classList.toggle("is-mobile-pane-list", pane === "list")
    layout.classList.toggle("is-mobile-pane-map", pane === "map")
    this.mobilePaneTargets.forEach((button) => {
      const active = button.dataset.pane === pane
      button.classList.toggle("btn-primary", active)
      button.classList.toggle("btn-outline-secondary", !active)
      button.setAttribute("aria-selected", active ? "true" : "false")
    })
    requestAnimationFrame(() => {
      if (this._map) this._map.resize()
      this._syncLegendPosition()
    })
  }

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
      this._syncLegendPosition()
      fn()
    })
  }

  _syncLegendPosition () {
    if (!this.hasLegendTarget) return
    const legend = this.legendTarget
    const layoutEl = this.hasLayoutTarget ? this.layoutTarget : this.element
    // Desktop keeps is-mobile-pane-list while still showing the map; only skip on real mobile list pane.
    if (isMapIndexMobileLayout(layoutEl) && layoutEl.classList.contains("is-mobile-pane-list")) return

    const layout = layoutEl.getBoundingClientRect()
    let insetLeft = 0
    let insetRight = 0
    const sidebar = this.element.querySelector(".destinations-sidebar")
    if (sidebar && !sidebar.classList.contains("slide-panel--collapsed") && !layoutEl.classList.contains("is-mobile-pane-map")) {
      const sr = sidebar.getBoundingClientRect()
      insetLeft = Math.max(0, Math.round(sr.right - layout.left))
    }
    const form = document.querySelector(".form-sidebar:not(.slide-panel--collapsed):not(.form-sidebar--collapsed)")
    if (form) {
      const fr = form.getBoundingClientRect()
      if (fr.width > 0) insetRight = Math.max(0, Math.round(layout.right - fr.left))
    }
    const visible = Math.max(0, layout.width - insetLeft - insetRight)
    const centerX = insetLeft + visible / 2
    legend.style.left = `${centerX}px`
    legend.style.right = "auto"
    legend.style.transform = "translateX(-50%)"
  }


  _bindSidebarChrome () {
    const sidebar = this.element.querySelector(".destinations-sidebar")
    const scheduleResize = () => {
      afterSlideTransition(sidebar, () => {
        if (this._map) this._map.resize()
        this._syncLegendPosition()
      })
    }
    this.element.addEventListener("click", (e) => {
      if (e.target.closest?.(".destinations-sidebar-toggle")) {
        sidebar?.classList.add("slide-panel--collapsed")
        scheduleResize()
        return
      }
      if (e.target.closest?.(".destinations-sidebar-expand")) {
        sidebar?.classList.remove("slide-panel--collapsed")
        scheduleResize()
        return
      }

      const row = e.target.closest?.(".store-row[data-customer-id]")
      if (!row) return
      if (e.target.closest?.("input[type=checkbox], a, button.btn-danger, .dropdown, .dropdown-menu")) return
      if (e.target.closest?.(".customers-row-center:disabled")) return

      const id = row.getAttribute("data-customer-id")
      if (!id) return
      const centerBtn = e.target.closest?.(".customers-row-center")
      this._focusCustomerInList(id, { flyToMap: true, revealMobileMap: !!centerBtn })
    }, { signal: this._abort.signal })
  }

  parseConfig () {
    try {
      return JSON.parse(this.element.dataset.config || "{}")
    } catch (_) {
      return {}
    }
  }

  async _initMap (maplibregl, container, params, signal) {
    const resolved = resolveMapStyle(params.map_layers || {})
    const { style, baseLayerIds, overlayToggles } = resolved
    const fromHash = parseMapViewHash()
    const map = attachMapToContainer(container, {
      style: style || { version: 8, sources: {}, layers: [] },
      center: fromHash ? fromHash.center : [2.35, 46.5],
      zoom: fromHash ? fromHash.zoom : 5,
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
    map.on("style.load", () => disableMapPitchAndRotation(map))
    this._map = map
    this._unbindMapViewHash = bindMapViewHash(map)

    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right")
    map.addControl(new maplibregl.ScaleControl({ maxWidth: 120, unit: "metric" }), "bottom-left")

    const { bases: basesOnly, overlays: overlayLayers } = pickLayers(params.map_layers || {})
    this._mapOverlayLayers = overlayLayers
    this._overlayToggles = overlayToggles || []
    this._overlayVisibility = {}
    this._overlayToggles.forEach((t) => {
      this._overlayVisibility[t.layerId] = !!t.initialVisible
    })
    const useStyleSwitch = resolved.mode === "vector" || basesNeedStyleSwitch(basesOnly)
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
      const layersTitle = params.map_layers_title || params.map_overlay_title || "Layers"
      map.addControl(new OverlayLayersToggleIControl(this._overlayToggles, layersTitle, {
        bases: baseSpecs,
        baseSectionTitle: params.map_base_layers_title || "",
        overlaySectionTitle: params.map_overlay_title || "",
        onBaseChange: useStyleSwitch ? (spec) => this._switchBaseLayer(spec) : null
      }), "top-right")
    }

    let features = []
    try {
      features = await this._fetchCustomersFeatures(signal)
    } catch (_) { /* network / abort */ }
    if (signal.aborted || this._map !== map) return
    this._mapFilterQ = new URLSearchParams(window.location.search).get("q") || ""

    this._mapLayersOptions = {
      staticFeatures: features,
      onPointClick: (feature) => this._handleMapPointClick(feature),
      onFeaturesUpdated: () => this._paintActiveCustomer(),
      isFeatureActive: (feature) => this._isActiveCustomerFeature(feature),
      getMovePadding: () => this._mapFlyToPadding(),
      signal
    }
    this._mapLayers = new DestinationsMapLayers(map, this._mapLayersOptions)
    this._mapLayers.connect({ refitBounds: !fromHash })

    if (overlayLayers.length && (resolved.mode === "vector" || overlayLayers.some((o) => o.vectorStyleUrl))) {
      const runOverlays = () => {
        this._syncOverlayVisibilityFromControl()
        applyOverlays(
          map,
          overlayLayers,
          this._overlayVisibility,
          this._overlayToggles,
          { includeRaster: resolved.mode === "vector", beforeId: CLUSTER_LAYER_ID }
        ).catch(() => { /* overlay style fetch failed */ })
      }
      if (map.isStyleLoaded()) runOverlays()
      else map.once("load", runOverlays)
    }

    const tDecluster = (typeof I18n !== "undefined" && I18n.t)
      ? I18n.t("destinations.index.map_decluster_viewport", { defaultValue: "Déclusteriser la vue" })
      : "Déclusteriser la vue"
    const tRecluster = (typeof I18n !== "undefined" && I18n.t)
      ? I18n.t("destinations.index.map_recluster_viewport", { defaultValue: "Clusteriser la vue" })
      : "Clusteriser la vue"
    this._declusterControl = new DeclusterViewportIControl({
      getDeclustered: () => !!(this._mapLayers && this._mapLayers.isDeclusterViewportActive()),
      onToggle: (declustered) => {
        if (!this._mapLayers) return
        this._mapLayers.setDeclusterViewportActive(declustered)
      },
      titleDecluster: tDecluster,
      titleRecluster: tRecluster
    })
    map.addControl(this._declusterControl, "top-right")

    scheduleMapResize(map)
    map.once("load", () => {
      scheduleMapResize(map)
      this._syncLegendPosition()
    })
  }

  _teardownMap () {
    this._activeCustomerId = null
    if (this._mapLayers) {
      this._mapLayers.disconnect()
      this._mapLayers = null
    }
    if (this.hasMapTarget) detachMapFromContainer(this.mapTarget)
    this._map = null
    this._declusterControl = null
  }

  _syncOverlayVisibilityFromControl () {
    const root = this.element.querySelector(".maplibre-overlay-toggles")
    if (!root || !this._overlayVisibility) return
    root.querySelectorAll('input[type="checkbox"][data-layer-id]').forEach((input) => {
      const id = input.getAttribute("data-layer-id")
      if (id) this._overlayVisibility[id] = !!input.checked
    })
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
    }
    this._map.once("style.load", reattach)
    this._map.setStyle(nextStyle, { diff: false })
  }

  _mapFlyToPadding () {
    return mapIndexFlyToPadding({
      layoutEl: this.element,
      leftSidebar: this.element.querySelector(".destinations-sidebar"),
      expandBtn: this.element.querySelector(".destinations-sidebar-expand"),
      formSidebar: document.querySelector(".form-sidebar"),
      mobile: isMapIndexMobileLayout(this.element)
    })
  }

  _customerRecord (idStr) {
    if (!this._mapLayers) return null
    return this._mapLayers.getDestination(idStr)
  }

  _isActiveCustomerFeature (feature) {
    return isFeatureActive(this._activeCustomerId, feature)
  }

  // Like operations: paint the Teritorio disc in place (incl. spidered leaves).
  // A separate MapLibre pin at true lng/lat lands in the middle of an unfolded group.
  _paintActiveCustomer () {
    const root = this.hasMapTarget ? this.mapTarget : this.element
    paintActiveDisc(root, this._activeCustomerId)
  }

  _clearCustomerHighlight () {
    this.element.querySelectorAll(".store-row").forEach((row) => row.classList.remove("highlight"))
    this._activeCustomerId = null
    this._paintActiveCustomer()
  }

  _scrollCustomerRowIntoView (row) {
    const box = this.element.querySelector("#customer_box")
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

  _currentPerPage () {
    const frame = document.getElementById("customers_list")
    const fromFrame = frame?.getAttribute("data-per-page")
    const fromUrl = new URL(window.location.href).searchParams.get("per_page")
    const raw = Number(fromFrame || fromUrl || 50)
    return [25, 50, 100].includes(raw) ? raw : 50
  }

  _buildCustomersIndexUrl (overrides = {}) {
    const url = new URL(window.location.pathname || "/customers", window.location.origin)
    url.searchParams.set("per_page", String(this._currentPerPage()))
    Object.entries(overrides).forEach(([key, val]) => {
      if (val === undefined || val === null || val === "") url.searchParams.delete(key)
      else url.searchParams.set(key, String(val))
    })
    return url.toString()
  }

  _stripHighlightParamFromUrl () {
    const url = new URL(window.location.href)
    if (!url.searchParams.has("highlight_customer_id")) return
    url.searchParams.delete("highlight_customer_id")
    window.history.replaceState(window.history.state || {}, "", url.toString())
  }

  _applyHighlightFromUrl () {
    const hid = new URL(window.location.href).searchParams.get("highlight_customer_id")
    if (!hid) return
    this._focusCustomerInList(String(hid), { flyToMap: false })
    this._stripHighlightParamFromUrl()
  }

  _onTurboFrameLoad (event) {
    const frame = event.target
    if (!frame || (frame.id !== "customers_list" && frame.id !== "customers_list_body")) return
    requestAnimationFrame(() => {
      this._applyHighlightFromUrl()
      if (this._map) this._map.resize()
      this._syncLegendPosition()
      this._syncMapFeaturesWithUrlFilter()
    })
  }

  async _fetchCustomersFeatures (signal) {
    const params = this.parseConfig()
    const url = new URL(params.map_geojson_url || "/customers.json", window.location.origin)
    url.searchParams.set("per_page", String(this._currentPerPage()))
    const pageQ = new URLSearchParams(window.location.search).get("q")
    if (pageQ) url.searchParams.set("q", pageQ)
    const res = await fetch(url.toString(), {
      headers: { Accept: "application/json" },
      signal: signal || this._abort?.signal
    })
    if (!res.ok) return []
    const data = await res.json()
    return customersToFeatures(data.customers || [])
  }

  /** Keep Teritorio pins aligned with server-filtered list when `q` changes. */
  async _syncMapFeaturesWithUrlFilter () {
    if (!this._mapLayers) return
    const q = new URLSearchParams(window.location.search).get("q") || ""
    if (q === (this._mapFilterQ || "")) return
    this._mapFilterQ = q
    try {
      const features = await this._fetchCustomersFeatures()
      if (!this._mapLayers) return
      this._mapLayers.replaceStaticFeatures(features)
    } catch (_) { /* abort / network */ }
  }

  _handleMapPointClick (feature) {
    const props = feature.properties || {}
    const idStr = String(props.id ?? "")
    if (!idStr) return

    const row = this.element.querySelector(`.store-row[data-customer-id="${CSS.escape(idStr)}"]`)
    if (row) {
      this._focusCustomerInList(idStr, { flyToMap: false })
      return
    }

    const page = Number(props.page)
    if (Number.isFinite(page) && page > 0) {
      // Highlight map pin immediately; list scroll happens after the turbo frame loads.
      this._focusCustomerInList(idStr, { flyToMap: false })
      visit(this._buildCustomersIndexUrl({ page, highlight_customer_id: idStr }), {
        frame: "customers_list",
        action: "advance"
      })
      return
    }

    this._focusCustomerInList(idStr, { flyToMap: false })
  }


  /**
   * @param {{ flyToMap?: boolean, revealMobileMap?: boolean }} [options]
   */
  _focusCustomerInList (idStr, options = {}) {
    const flyToMap = !!options.flyToMap
    const revealMobileMap = !!options.revealMobileMap
    this._clearCustomerHighlight()

    let rec = this._customerRecord(idStr)
    const rows = Array.from(this.element.querySelectorAll(".store-row")).filter(
      (row) => row.getAttribute("data-customer-id") === String(idStr)
    )
    const row = rows[0]
    if (!rec && row) {
      const lat = parseFloat(row.getAttribute("data-lat"))
      const lng = parseFloat(row.getAttribute("data-lng"))
      if (Number.isFinite(lat) && Number.isFinite(lng)) {
        rec = { lngLat: [lng, lat], name: "" }
      }
    }

    this._activeCustomerId = String(idStr)
    this._paintActiveCustomer()

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
          this._syncLegendPosition()
          // Teritorio rebuilds markers after move; re-apply active class.
          map.once("moveend", () => this._paintActiveCustomer())
        })
      }
      if (revealMobileMap) this._withMobileMapVisible(runFly)
      else runFly()
    }

    if (rows.length) {
      rows.forEach((r) => r.classList.add("highlight"))
      this._scrollCustomerRowIntoView(row)
    }
  }
}
