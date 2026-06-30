// Copyright © Cartoway
// Clustered GeoJSON layers for the v2 destinations map (bbox loading, GPU rendering).

export const SOURCE_ID = 'destinations-v2'
export const CLUSTER_LAYER_ID = 'destinations-v2-clusters'
export const CLUSTER_COUNT_LAYER_ID = 'destinations-v2-cluster-count'
export const UNCLUSTERED_LAYER_ID = 'destinations-v2-unclustered'
export const DECLUSTER_SOURCE_ID = 'destinations-v2-decluster-viewport'
export const DECLUSTER_LAYER_ID = 'destinations-v2-decluster-viewport-points'

const CLUSTER_MAX_ZOOM = 14
const CLUSTER_RADIUS = 50
const FETCH_DEBOUNCE_MS = 300
const BBOX_PADDING_RATIO = 0.35
const PRUNE_MARGIN_RATIO = 2.5

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
  constructor (map, { buildUrl, onPointClick, onClusterClick, onFeaturesUpdated, signal }) {
    this.map = map
    this.buildUrl = buildUrl
    this.onPointClick = onPointClick
    this.onClusterClick = onClusterClick
    this.onFeaturesUpdated = onFeaturesUpdated
    this.signal = signal
    this._featureCache = new Map()
    this._hiddenIds = new Set()
    this._fetchTimer = null
    this._fetchAbort = null
    this._loadedBounds = null
    this._layersReady = false
    this._declusterViewportActive = false
    this._boundHandlers = {
      moveend: () => this._onMoveEnd(),
      clickCluster: (e) => this._handleClusterClick(e),
      clickPoint: (e) => this._handlePointClick(e)
    }
  }

  connect () {
    const run = () => {
      this._ensureLayers()
      this._loadInitialViewport()
    }
    if (this.map.loaded()) run()
    else this.map.once('load', run)
  }

  async _loadInitialViewport () {
    await this._fetchBoundsOnly()
    await this._fetchViewport({ force: true })
    this._bindEvents()
  }

  disconnect () {
    window.clearTimeout(this._fetchTimer)
    this._fetchTimer = null
    if (this._fetchAbort) this._fetchAbort.abort()
    this._fetchAbort = null
    this._unbindEvents()
    this._removeLayers()
    this._featureCache.clear()
    this._hiddenIds.clear()
    this._declusterViewportActive = false
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
    this._updateUnclusteredFilter()
    this._pushSourceData()
  }

  updateDestinationCoords (idStr, lng, lat) {
    const key = String(idStr)
    const existing = this._featureCache.get(key)
    if (!existing) return
    existing.geometry.coordinates = [lng, lat]
    this._pushSourceData()
  }

  async reload (options = {}) {
    const fitBounds = options.fitBounds !== false
    this._loadedBounds = null
    this._declusterViewportActive = false
    this._featureCache.clear()
    this._pushSourceData()
    this._setClusterLayersVisible(true)
    if (fitBounds) await this._fetchBoundsOnly()
    await this._fetchViewport({ force: true })
  }

  declusterViewport () {
    if (!this._layersReady) return
    this._ensureDeclusterLayer()
    this._declusterViewportActive = true
    this._pushSourceData()
  }

  _onMoveEnd () {
    this._scheduleFetch()
    if (this._declusterViewportActive) this._pushSourceData()
  }

  _ensureDeclusterLayer () {
    if (this.map.getSource(DECLUSTER_SOURCE_ID)) return

    this.map.addSource(DECLUSTER_SOURCE_ID, {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] }
    })

    this.map.addLayer({
      id: DECLUSTER_LAYER_ID,
      type: 'circle',
      source: DECLUSTER_SOURCE_ID,
      layout: { visibility: 'none' },
      paint: {
        'circle-color': '#0d6efd',
        'circle-radius': 7,
        'circle-stroke-width': 2,
        'circle-stroke-color': '#ffffff'
      }
    })
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

  _syncDeclusterViewportLayer () {
    if (!this._declusterViewportActive) return

    this._ensureDeclusterLayer()
    const source = this.map.getSource(DECLUSTER_SOURCE_ID)
    if (!source) return

    source.setData({
      type: 'FeatureCollection',
      features: this._featuresInMapBounds()
    })
    if (this.map.getLayer(DECLUSTER_LAYER_ID)) {
      this.map.setLayoutProperty(DECLUSTER_LAYER_ID, 'visibility', 'visible')
    }
  }

  _setClusterLayersVisible (visible) {
    const layoutVisibility = visible ? 'visible' : 'none'
    ;[CLUSTER_LAYER_ID, CLUSTER_COUNT_LAYER_ID, UNCLUSTERED_LAYER_ID].forEach((id) => {
      if (this.map.getLayer(id)) this.map.setLayoutProperty(id, 'visibility', layoutVisibility)
    })
    if (this.map.getLayer(DECLUSTER_LAYER_ID)) {
      this.map.setLayoutProperty(DECLUSTER_LAYER_ID, 'visibility', 'none')
    }
  }

  _ensureLayers () {
    if (this._layersReady) return
    this.map.addSource(SOURCE_ID, {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
      cluster: true,
      clusterMaxZoom: CLUSTER_MAX_ZOOM,
      clusterRadius: CLUSTER_RADIUS
    })

    this.map.addLayer({
      id: CLUSTER_LAYER_ID,
      type: 'circle',
      source: SOURCE_ID,
      filter: ['has', 'point_count'],
      paint: {
        'circle-color': '#0d6efd',
        'circle-radius': ['step', ['get', 'point_count'], 16, 25, 20, 100, 26],
        'circle-stroke-width': 2,
        'circle-stroke-color': '#ffffff'
      }
    })

    this.map.addLayer({
      id: CLUSTER_COUNT_LAYER_ID,
      type: 'symbol',
      source: SOURCE_ID,
      filter: ['has', 'point_count'],
      layout: {
        'text-field': ['get', 'point_count_abbreviated'],
        'text-font': ['Open Sans Bold', 'Arial Unicode MS Bold'],
        'text-size': 12
      },
      paint: {
        'text-color': '#ffffff'
      }
    })

    this.map.addLayer({
      id: UNCLUSTERED_LAYER_ID,
      type: 'circle',
      source: SOURCE_ID,
      filter: this._unclusteredFilter(),
      paint: {
        'circle-color': '#0d6efd',
        'circle-radius': 7,
        'circle-stroke-width': 2,
        'circle-stroke-color': '#ffffff'
      }
    })

    this._layersReady = true
  }

  _unclusteredFilter () {
    const hidden = Array.from(this._hiddenIds)
    const base = ['!', ['has', 'point_count']]
    if (hidden.length === 0) return base
    return ['all', base, ['!', ['in', ['to-string', ['get', 'id']], ['literal', hidden]]]]
  }

  _updateUnclusteredFilter () {
    if (!this._layersReady || !this.map.getLayer(UNCLUSTERED_LAYER_ID)) return
    this.map.setFilter(UNCLUSTERED_LAYER_ID, this._unclusteredFilter())
  }

  _bindEvents () {
    this.map.on('moveend', this._boundHandlers.moveend)
    this.map.on('click', CLUSTER_LAYER_ID, this._boundHandlers.clickCluster)
    this.map.on('click', CLUSTER_COUNT_LAYER_ID, this._boundHandlers.clickCluster)
    this.map.on('click', UNCLUSTERED_LAYER_ID, this._boundHandlers.clickPoint)
    this.map.on('click', DECLUSTER_LAYER_ID, this._boundHandlers.clickPoint)
    this.map.on('mouseenter', CLUSTER_LAYER_ID, () => { this.map.getCanvas().style.cursor = 'pointer' })
    this.map.on('mouseleave', CLUSTER_LAYER_ID, () => { this.map.getCanvas().style.cursor = '' })
    this.map.on('mouseenter', CLUSTER_COUNT_LAYER_ID, () => { this.map.getCanvas().style.cursor = 'pointer' })
    this.map.on('mouseleave', CLUSTER_COUNT_LAYER_ID, () => { this.map.getCanvas().style.cursor = '' })
    this.map.on('mouseenter', UNCLUSTERED_LAYER_ID, () => { this.map.getCanvas().style.cursor = 'pointer' })
    this.map.on('mouseleave', UNCLUSTERED_LAYER_ID, () => { this.map.getCanvas().style.cursor = '' })
    this.map.on('mouseenter', DECLUSTER_LAYER_ID, () => { this.map.getCanvas().style.cursor = 'pointer' })
    this.map.on('mouseleave', DECLUSTER_LAYER_ID, () => { this.map.getCanvas().style.cursor = '' })
  }

  _unbindEvents () {
    if (!this.map) return
    this.map.off('moveend', this._boundHandlers.moveend)
    this.map.off('click', CLUSTER_LAYER_ID, this._boundHandlers.clickCluster)
    this.map.off('click', CLUSTER_COUNT_LAYER_ID, this._boundHandlers.clickCluster)
    this.map.off('click', UNCLUSTERED_LAYER_ID, this._boundHandlers.clickPoint)
    this.map.off('click', DECLUSTER_LAYER_ID, this._boundHandlers.clickPoint)
  }

  _removeLayers () {
    if (!this._layersReady) return
    ;[DECLUSTER_LAYER_ID, UNCLUSTERED_LAYER_ID, CLUSTER_COUNT_LAYER_ID, CLUSTER_LAYER_ID].forEach((id) => {
      if (this.map.getLayer(id)) this.map.removeLayer(id)
    })
    ;[DECLUSTER_SOURCE_ID, SOURCE_ID].forEach((id) => {
      if (this.map.getSource(id)) this.map.removeSource(id)
    })
    this._layersReady = false
    this._declusterViewportActive = false
  }

  _scheduleFetch (immediate = false) {
    window.clearTimeout(this._fetchTimer)
    const run = () => {
      this._fetchTimer = null
      this._fetchViewport()
    }
    if (immediate) run()
    else this._fetchTimer = window.setTimeout(run, FETCH_DEBOUNCE_MS)
  }

  async _fetchBoundsOnly () {
    const url = this.buildUrl({ bounds_only: '1' })
    try {
      const res = await fetch(url, { credentials: 'same-origin', signal: this.signal })
      if (!res.ok) return
      const data = await res.json()
      if (!data.bounds) return
      const maplibregl = window.maplibregl
      if (!maplibregl) return
      const bounds = new maplibregl.LngLatBounds(data.bounds[0], data.bounds[1])
      this.map.fitBounds(bounds, { padding: 48, maxZoom: 15, duration: 0 })
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
    const bounds = paddedBounds(this.map)
    if (!force && this._loadedBounds && this._containsBounds(this._loadedBounds, bounds)) return

    const url = this.buildUrl({ bbox: boundsToParam(bounds) })
    if (this._fetchAbort) this._fetchAbort.abort()
    this._fetchAbort = new AbortController()

    try {
      const res = await fetch(url, { credentials: 'same-origin', signal: this._fetchAbort.signal })
      if (!res.ok) return
      const data = await res.json()
      const features = data.features || []
      if (features.length === 0 && !force) {
        this._loadedBounds = null
        return
      }
      this._mergeFeatures(features)
      this._pruneCache(bounds)
      this._pushSourceData()
      if (features.length > 0) this._loadedBounds = bounds
      if (this.onFeaturesUpdated) this.onFeaturesUpdated()
    } catch (e) {
      if (e.name === 'AbortError') return
    } finally {
      this._fetchAbort = null
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

    if (this._declusterViewportActive) {
      source.setData({
        type: 'FeatureCollection',
        features: this._featuresOutsideMapBounds()
      })
      this._syncDeclusterViewportLayer()
      return
    }

    source.setData({
      type: 'FeatureCollection',
      features: this._visibleFeatures()
    })
    if (this.map.getLayer(DECLUSTER_LAYER_ID)) {
      this.map.setLayoutProperty(DECLUSTER_LAYER_ID, 'visibility', 'none')
    }
  }

  _handleClusterClick (e) {
    const feature = e.features && e.features[0]
    if (!feature) return
    if (e.originalEvent) e.originalEvent.stopPropagation()
    this.map.easeTo({
      center: feature.geometry.coordinates,
      zoom: this.map.getZoom() + 1,
      duration: 250
    })
    if (this.onClusterClick) this.onClusterClick(e)
  }

  _handlePointClick (e) {
    const feature = e.features && e.features[0]
    if (!feature || !this.onPointClick) return
    e.originalEvent.stopPropagation()
    this.onPointClick(feature)
  }
}
