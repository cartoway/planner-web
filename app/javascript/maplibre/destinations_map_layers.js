// Copyright © Cartoway
// Clustered GeoJSON for the v2 destinations/stores map.
// Points are HTML markers (not GL circles); clustering is done by
// @teritorio/maplibre-gl-teritorio-cluster on top of a MapLibre GeoJSON source.

import { TeritorioCluster } from '@teritorio/maplibre-gl-teritorio-cluster'
import {
  fillClusterMarker,
  fillDestinationMarker,
  geojsonClusterSourceOptions,
  UNFOLDED_CLUSTER_MAX_LEAVES,
  teritorioClusterOptions
} from 'maplibre/destination_markers'
import { pointsToFeatures } from 'maplibre/map_points'

export const SOURCE_ID = 'destinations-v2'
export const CLUSTER_LAYER_ID = 'destinations-v2-clusters'
export const DECLUSTER_SOURCE_ID = 'destinations-v2-decluster-viewport'
export const DECLUSTER_LAYER_ID = 'destinations-v2-decluster-viewport-points'

const FETCH_DEBOUNCE_MS = 300
const BBOX_PADDING_RATIO = 0.35
const PRUNE_MARGIN_RATIO = 2.5
// OSM (and most raster bases) stop around z19. Cluster fitBounds above that 400s tiles.
// Stacked leaves spider in place instead of chasing z22+.
export const CLUSTER_FIT_MAX_ZOOM = 18

function paddedBounds (map) {
  const b = map.getBounds()
  const lngSpan = b.getEast() - b.getWest()
  const latSpan = b.getNorth() - b.getSouth()
  const padLng = lngSpan * BBOX_PADDING_RATIO
  const padLat = latSpan * BBOX_PADDING_RATIO
  return {
    west: b.getWest() - padLng,
    south: b.getSouth() - padLat,
    east: b.getEast() + padLng,
    north: b.getNorth() + padLat
  }
}

function boundsToParam ({ west, south, east, north }) {
  return `${west},${south},${east},${north}`
}

function featureKey (feature) {
  const id = feature.properties && feature.properties.id
  return id != null ? String(id) : null
}

export class DestinationsMapLayers {
  constructor (map, { buildUrl, staticFeatures, onPointClick, onFeaturesUpdated, isFeatureActive, getMovePadding, signal }) {
    this.map = map
    this.buildUrl = buildUrl
    this.staticFeatures = Array.isArray(staticFeatures) ? staticFeatures : null
    this.onPointClick = onPointClick
    this.onFeaturesUpdated = onFeaturesUpdated
    this.isFeatureActive = isFeatureActive
    this.getMovePadding = getMovePadding
    this.signal = signal
    this._featureCache = new Map()
    this._hiddenIds = new Set()
    this._fetchTimer = null
    this._fetchAbort = null
    this._loadedBounds = null
    this._layersReady = false
    this._eventsBound = false
    this._dataEpoch = 0
    this._declusterViewportActive = false
    this._cluster = null
    this._declusterCluster = null
    this._disposed = false
    // Raised on cluster click when leaves cannot be separated by zoom (stacked points).
    this._unfoldedClusterMaxLeaves = null
    this._boundHandlers = {
      moveend: () => this._onMoveEnd(),
      resize: () => this._syncFitBoundsOptions(),
      featureClick: (event) => this._handleFeatureClick(event)
    }
  }

  connect (options = {}) {
    this._disposed = false
    const refitBounds = options.refitBounds !== false
    const force = !!options.force
    const run = () => {
      this._ensureLayers().then(() => {
        if (this._disposed) return
        this._bindEvents()
        this._loadInitialViewport({ refitBounds })
      }).catch(() => {
        // Style switch can leave the map briefly unable to accept layers; retry once on idle.
        if (this._disposed || this._connectRetryScheduled) return
        this._connectRetryScheduled = true
        this.map.once('idle', () => {
          this._connectRetryScheduled = false
          run()
        })
      })
    }
    // force: caller already waited for style.load (setStyle). Avoid racy map.loaded()/'load'.
    if (force || this.map.isStyleLoaded()) {
      run()
    } else {
      this.map.once('load', run)
    }
  }

  async _loadInitialViewport ({ refitBounds = true } = {}) {
    const epoch = this._dataEpoch
    if (refitBounds) {
      await this._fetchBoundsOnly(epoch)
      if (!this._isCurrentEpoch(epoch)) return
    }
    await this._fetchViewport({ force: true, epoch })
  }

  disconnect () {
    this._disposed = true
    this._dataEpoch += 1
    window.clearTimeout(this._fetchTimer)
    this._fetchTimer = null
    if (this._fetchAbort) this._fetchAbort.abort()
    this._fetchAbort = null
    this._unbindEvents()
    this._removeLayers()
    this._featureCache.clear()
    this._hiddenIds.clear()
    this._unfoldedClusterMaxLeaves = null
    this._declusterViewportActive = false
  }

  /** Replace static point set (customers index filter) and redraw clusters. */
  replaceStaticFeatures (features) {
    if (!this._isStatic() || this._disposed) return
    this.staticFeatures = Array.isArray(features) ? features : []
    this._featureCache.clear()
    this._mergeFeatures(this.staticFeatures)
    this._pushSourceData()
    if (this.onFeaturesUpdated) this.onFeaturesUpdated()
  }

  _isCurrentEpoch (epoch) {
    return epoch === this._dataEpoch
  }

  _beginDataEpoch () {
    this._dataEpoch += 1
    return this._dataEpoch
  }

  getDestination (idStr) {
    const f = this._featureCache.get(String(idStr))
    if (!f) return null
    const [lng, lat] = f.geometry.coordinates
    return {
      id: f.properties.id,
      name: f.properties.name,
      page: f.properties.page,
      lngLat: [lng, lat]
    }
  }

  removeDestination (idStr) {
    this._featureCache.delete(String(idStr))
    this._hiddenIds.delete(String(idStr))
    this._pushSourceData()
  }

  setHiddenDestinationIds (ids) {
    this._hiddenIds = new Set((ids || []).map((id) => String(id)))
    // Hide the on-screen disc now. Source refresh (and Teritorio) catches up after, too late
    // if a flyTo has already started: the yellow marker would slide onto the blue one.
    this._concealHiddenMarkers()
    this._pushSourceData()
  }

  _concealHiddenMarkers () {
    const container = this.map && this.map.getContainer && this.map.getContainer()
    if (!container || this._hiddenIds.size === 0) return
    this._hiddenIds.forEach((id) => {
      let node = null
      try {
        // Only Teritorio discs use the feature id. Edit pins are --dom-pin without id.
        node = container.querySelector(`.destinations-marker[id="${CSS.escape(id)}"]:not(.destinations-marker--dom-pin)`)
      } catch (e) {
        return
      }
      // Hide even --active discs: position-edit uses a separate DOM pin, and leaving the
      // yellow Teritorio disc visible keeps a stale active colour after form switches.
      if (!node) return
      node.classList.remove('destinations-marker--active')
      node.style.visibility = 'hidden'
    })
  }

  updateDestinationCoords (idStr, lng, lat) {
    const key = String(idStr)
    const existing = this._featureCache.get(key)
    if (!existing) return
    existing.geometry.coordinates = [lng, lat]
    this._pushSourceData()
  }

  async reload (options = {}) {
    const epoch = this._beginDataEpoch()
    window.clearTimeout(this._fetchTimer)
    this._fetchTimer = null
    if (this._fetchAbort) {
      this._fetchAbort.abort()
      this._fetchAbort = null
    }

    const fitBounds = options.fitBounds !== false
    this._loadedBounds = null
    this._declusterViewportActive = false
    this._unfoldedClusterMaxLeaves = null
    this._featureCache.clear()
    this._syncUnfoldedClusterMaxLeaves()

    // Filter applied before the map finished loading: initial viewport will use this epoch + current filters.
    if (!this._layersReady) return

    this._pushSourceData()
    if (fitBounds) await this._fetchBoundsOnly(epoch)
    if (!this._isCurrentEpoch(epoch)) return
    await this._fetchViewport({ force: true, epoch })
  }

  declusterViewport () {
    if (!this._layersReady) return
    this._declusterViewportActive = true
    this._pushSourceData()
  }

  reclusterViewport () {
    if (!this._layersReady) return
    this._declusterViewportActive = false
    this._pushSourceData()
  }

  isDeclusterViewportActive () {
    return this._declusterViewportActive
  }

  setDeclusterViewportActive (active) {
    if (active) this.declusterViewport()
    else this.reclusterViewport()
  }

  _isStatic () {
    return Array.isArray(this.staticFeatures)
  }

  _onMoveEnd () {
    this._syncFitBoundsOptions()
    this._scheduleFetch()
    if (this._declusterViewportActive) this._pushSourceData()
  }

  _syncFitBoundsOptions () {
    const padding = typeof this.getMovePadding === 'function' ? this.getMovePadding() : 48
    const options = { padding: padding || 48, maxZoom: CLUSTER_FIT_MAX_ZOOM }
    if (this._cluster) this._cluster.setBoundsOptions(options)
    if (this._declusterCluster) this._declusterCluster.setBoundsOptions(options)
  }

  _visibleFeatures () {
    return Array.from(this._featureCache.values()).filter((f) => {
      const key = featureKey(f)
      return !key || !this._hiddenIds.has(key)
    })
  }

  _featuresInMapBounds () {
    const bounds = this.map.getBounds()
    const west = bounds.getWest()
    const east = bounds.getEast()
    const south = bounds.getSouth()
    const north = bounds.getNorth()

    return this._visibleFeatures().filter((f) => {
      const [lng, lat] = f.geometry.coordinates
      return lng >= west && lng <= east && lat >= south && lat <= north
    })
  }

  _featuresOutsideMapBounds () {
    const bounds = this.map.getBounds()
    const west = bounds.getWest()
    const east = bounds.getEast()
    const south = bounds.getSouth()
    const north = bounds.getNorth()

    return this._visibleFeatures().filter((f) => {
      const [lng, lat] = f.geometry.coordinates
      return lng < west || lng > east || lat < south || lat > north
    })
  }

  _ensureLayers () {
    if (this._layersReady) return Promise.resolve()
    if (this._ensurePromise) return this._ensurePromise
    this._ensurePromise = this._setupLayers().finally(() => {
      this._ensurePromise = null
    })
    return this._ensurePromise
  }

  async _setupLayers () {
    if (this._layersReady || this._disposed) return

    if (!this.map.getSource(SOURCE_ID)) {
      this.map.addSource(SOURCE_ID, {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
        ...geojsonClusterSourceOptions()
      })
    }

    if (!this.map.getSource(DECLUSTER_SOURCE_ID)) {
      // Unclustered: Teritorio renders each feature as an HTML marker.
      this.map.addSource(DECLUSTER_SOURCE_ID, {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] }
      })
    }

    if (!this.map.getLayer(CLUSTER_LAYER_ID)) {
      this._cluster = this._createClusterLayer(CLUSTER_LAYER_ID, SOURCE_ID)
      this.map.addLayer(this._cluster)
    }
    if (!this.map.getLayer(DECLUSTER_LAYER_ID)) {
      this._declusterCluster = this._createClusterLayer(DECLUSTER_LAYER_ID, DECLUSTER_SOURCE_ID)
      this.map.addLayer(this._declusterCluster)
    }

    this._layersReady = true
    this._syncFitBoundsOptions()
  }

  _createClusterLayer (id, sourceId) {
    const maplibregl = window.maplibregl
    const layer = new TeritorioCluster(id, sourceId, teritorioClusterOptions({
      clusterRender (element, props) {
        fillClusterMarker(element, props)
      },
      markerRender: (element, _markerSize, feature) => {
        const props = feature && feature.properties
        const name = props && props.name
        fillDestinationMarker(element, {
          name,
          anchored: true,
          status: props && props.status,
          color: props && props.color
        })
        if (typeof this.isFeatureActive === 'function' && this.isFeatureActive(feature)) {
          element.classList.add('destinations-marker--active')
        }
      },

      pinMarkerRender (coords, offset) {
        // Index selection paints the Teritorio disc; destinations/stores may still
        // add a MapLibre DOM pin for position edit. Keep Teritorio's pin invisible.
        const el = document.createElement('div')
        el.className = 'destinations-marker-pin-placeholder'
        const marker = new maplibregl.Marker({ element: el }).setLngLat(coords)
        if (offset) marker.setOffset(offset)
        return marker
      }
    }))
    this._patchClusterExpand(layer)
    layer.addEventListener('feature-click', this._boundHandlers.featureClick)
    return layer
  }

  // Teritorio cluster click → fitBounds (tile-safe maxZoom). Stacked / still-tight
  // leaves: raise unfoldedClusterMaxLeaves and re-render so Teritorio spiders.
  _patchClusterExpand (layer) {
    if (!layer || layer._cartowayExpandPatched) return
    layer._cartowayExpandPatched = true
    const original = layer.fitBoundsToClusterLeaves.bind(layer)
    layer.fitBoundsToClusterLeaves = (features) => {
      const leaves = features || []
      if (leaves.length === 0) return
      if (this._clusterLeavesAreStacked(leaves)) {
        this._spiderClusterLeaves(leaves.length)
        return
      }
      original(leaves)
      this.map.once('moveend', () => {
        if (this._disposed || !layer.map) return
        // Hit tile-safe ceiling or leaves still share one point → spider in place.
        if (this._clusterLeavesAreStacked(leaves) ||
            this.map.getZoom() >= CLUSTER_FIT_MAX_ZOOM - 0.05) {
          this._spiderClusterLeaves(leaves.length)
        }
      })
    }
  }

  _clusterLeavesAreStacked (features) {
    const coords = (features || [])
      .map((f) => f.geometry && f.geometry.coordinates)
      .filter((c) => c && c.length >= 2)
    if (coords.length < 2) return false
    let minLng = coords[0][0]
    let maxLng = coords[0][0]
    let minLat = coords[0][1]
    let maxLat = coords[0][1]
    for (let i = 1; i < coords.length; i++) {
      const [lng, lat] = coords[i]
      if (lng < minLng) minLng = lng
      if (lng > maxLng) maxLng = lng
      if (lat < minLat) minLat = lat
      if (lat > maxLat) maxLat = lat
    }
    // ~1m-scale span: zoom cannot visually separate these pins.
    return Math.max(maxLng - minLng, maxLat - minLat) < 1e-5
  }

  _spiderClusterLeaves (leafCount) {
    const n = Number(leafCount) || 0
    if (n <= 0) return
    const prev = this._unfoldedClusterMaxLeaves
    this._unfoldedClusterMaxLeaves = Math.max(prev || 0, n)
    if (this._unfoldedClusterMaxLeaves === prev) {
      // Cap already high enough but markers may still be a bubble — force re-render.
      this._rerenderClusters()
      return
    }
    this._syncUnfoldedClusterMaxLeaves()
    this._rerenderClusters()
  }

  _syncUnfoldedClusterMaxLeaves () {
    const n = this._unfoldedClusterMaxLeaves
    ;[this._cluster, this._declusterCluster].forEach((layer) => {
      if (!layer || !layer.opts) return
      layer.opts.unfoldedClusterMaxLeaves = n == null
        ? UNFOLDED_CLUSTER_MAX_LEAVES
        : Math.max(UNFOLDED_CLUSTER_MAX_LEAVES, n)
    })
  }

  _rerenderClusters () {
    ;[this._cluster, this._declusterCluster].forEach((layer) => {
      if (!layer || typeof layer.renderCustom !== 'function') return
      layer.abortExec += 1
      layer.renderCustom(layer.abortExec)
    })
  }

  _handleFeatureClick (event) {
    const feature = event.detail && event.detail.selectedFeature
    if (this._cluster) this._cluster.resetSelectedFeature()
    if (this._declusterCluster) this._declusterCluster.resetSelectedFeature()
    if (feature && this.onPointClick) this.onPointClick(feature)
  }

  _bindEvents () {
    if (this._eventsBound) return
    this.map.on('moveend', this._boundHandlers.moveend)
    this.map.on('resize', this._boundHandlers.resize)
    this._eventsBound = true
  }

  _unbindEvents () {
    if (!this.map || !this._eventsBound) return
    this.map.off('moveend', this._boundHandlers.moveend)
    this.map.off('resize', this._boundHandlers.resize)
    this._eventsBound = false
  }

  _removeLayers () {
    if (!this._layersReady) return
    ;[this._declusterCluster, this._cluster].forEach((layer) => {
      if (layer) layer.removeEventListener('feature-click', this._boundHandlers.featureClick)
    })
    ;[DECLUSTER_LAYER_ID, CLUSTER_LAYER_ID].forEach((id) => {
      if (this.map.getLayer(id)) this.map.removeLayer(id)
    })
    ;[DECLUSTER_SOURCE_ID, SOURCE_ID].forEach((id) => {
      if (this.map.getSource(id)) this.map.removeSource(id)
    })
    this._cluster = null
    this._declusterCluster = null
    this._layersReady = false
    this._declusterViewportActive = false
  }

  _scheduleFetch (immediate = false) {
    if (this._isStatic()) {
      if (this._declusterViewportActive) this._pushSourceData()
      return
    }
    window.clearTimeout(this._fetchTimer)
    const run = () => {
      this._fetchTimer = null
      this._fetchViewport()
    }
    if (immediate) run()
    else this._fetchTimer = window.setTimeout(run, FETCH_DEBOUNCE_MS)
  }

  _fitStaticBounds () {
    const maplibregl = window.maplibregl
    if (!maplibregl || !this.staticFeatures.length) return
    const coords = this.staticFeatures
      .map((f) => f.geometry && f.geometry.coordinates)
      .filter((c) => Array.isArray(c) && c.length >= 2 && Number.isFinite(c[0]) && Number.isFinite(c[1]))
    if (!coords.length) return
    const padding = typeof this.getMovePadding === 'function' ? this.getMovePadding() : 48
    if (coords.length === 1) {
      this.map.setCenter(coords[0])
      this.map.setZoom(12)
      return
    }
    const bounds = coords.reduce((b, c) => b.extend(c), new maplibregl.LngLatBounds(coords[0], coords[0]))
    this.map.fitBounds(bounds, { padding: padding || 48, maxZoom: 15, duration: 0 })
  }

  async _fetchBoundsOnly (epoch = this._dataEpoch) {
    if (this._isStatic()) {
      if (!this._isCurrentEpoch(epoch)) return
      this._fitStaticBounds()
      this._loadedBounds = null
      await new Promise((resolve) => {
        if (this.map.isMoving()) this.map.once('idle', resolve)
        else resolve()
      })
      return
    }
    const url = this.buildUrl({ bounds_only: '1' })
    try {
      const res = await fetch(url, { credentials: 'same-origin', signal: this.signal })
      if (!res.ok || !this._isCurrentEpoch(epoch)) return
      const data = await res.json()
      if (!this._isCurrentEpoch(epoch) || !data.bounds) return
      const maplibregl = window.maplibregl
      if (!maplibregl) return
      const bounds = new maplibregl.LngLatBounds(data.bounds[0], data.bounds[1])
      const padding = typeof this.getMovePadding === 'function' ? this.getMovePadding() : 48
      this.map.fitBounds(bounds, { padding: padding || 48, maxZoom: 15, duration: 0 })
      this._loadedBounds = null
      await new Promise((resolve) => {
        if (this.map.isMoving()) this.map.once('idle', resolve)
        else resolve()
      })
    } catch (e) {
      if (e.name === 'AbortError') return
    }
  }

  async _fetchViewport (options = {}) {
    const force = !!options.force
    const epoch = options.epoch != null ? options.epoch : this._dataEpoch
    if (this._isStatic()) {
      if (!this._isCurrentEpoch(epoch)) return
      if (force) this._featureCache.clear()
      this._mergeFeatures(this.staticFeatures)
      this._pushSourceData()
      if (this.onFeaturesUpdated) this.onFeaturesUpdated()
      return
    }
    const bounds = paddedBounds(this.map)
    if (!force && this._loadedBounds && this._containsBounds(this._loadedBounds, bounds)) return

    const url = this.buildUrl({ bbox: boundsToParam(bounds) })
    if (this._fetchAbort) this._fetchAbort.abort()
    this._fetchAbort = new AbortController()
    const fetchAbort = this._fetchAbort

    try {
      const res = await fetch(url, { credentials: 'same-origin', signal: fetchAbort.signal })
      if (!res.ok || !this._isCurrentEpoch(epoch)) return
      const data = await res.json()
      if (!this._isCurrentEpoch(epoch)) return
      const features = pointsToFeatures(data.points)
      if (features.length === 0 && !force) {
        this._loadedBounds = null
        return
      }
      // force (initial/reload): replace cache so a stale unfiltered response cannot linger via merge.
      if (force) this._featureCache.clear()
      this._mergeFeatures(features)
      if (!force) this._pruneCache(bounds)
      this._pushSourceData()
      if (features.length > 0) this._loadedBounds = bounds
      if (this.onFeaturesUpdated) this.onFeaturesUpdated()
    } catch (e) {
      if (e.name === 'AbortError') return
    } finally {
      if (this._fetchAbort === fetchAbort) this._fetchAbort = null
    }
  }

  _containsBounds (outer, inner) {
    return inner.west >= outer.west &&
      inner.south >= outer.south &&
      inner.east <= outer.east &&
      inner.north <= outer.north
  }

  _mergeFeatures (features) {
    features.forEach((f) => {
      const key = featureKey(f)
      if (key) this._featureCache.set(key, f)
    })
  }

  _pruneCache (viewportBounds) {
    const marginLng = (viewportBounds.east - viewportBounds.west) * PRUNE_MARGIN_RATIO
    const marginLat = (viewportBounds.north - viewportBounds.south) * PRUNE_MARGIN_RATIO
    const minLng = viewportBounds.west - marginLng
    const maxLng = viewportBounds.east + marginLng
    const minLat = viewportBounds.south - marginLat
    const maxLat = viewportBounds.north + marginLat

    this._featureCache.forEach((f, key) => {
      if (this._hiddenIds.has(key)) return
      const [lng, lat] = f.geometry.coordinates
      if (lng < minLng || lng > maxLng || lat < minLat || lat > maxLat) {
        this._featureCache.delete(key)
      }
    })
  }

  _pushSourceData () {
    const source = this.map.getSource(SOURCE_ID)
    if (!source) return
    const declusterSource = this.map.getSource(DECLUSTER_SOURCE_ID)

    if (this._declusterViewportActive) {
      source.setData({
        type: 'FeatureCollection',
        features: this._featuresOutsideMapBounds()
      })
      if (declusterSource) {
        declusterSource.setData({
          type: 'FeatureCollection',
          features: this._featuresInMapBounds()
        })
      }
      return
    }

    source.setData({
      type: 'FeatureCollection',
      features: this._visibleFeatures()
    })
    if (declusterSource) {
      declusterSource.setData({ type: 'FeatureCollection', features: [] })
    }
  }
}
