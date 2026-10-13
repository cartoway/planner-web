// Delivery tracking public map (MapLibre) — destination pin + vehicle pin / accuracy halo / track
import { Controller } from '@hotwired/stimulus'
import { resolveMapStyle } from 'maplibre/raster_layers'
import {
  attachMapToContainer,
  bindTurboMapHost,
  detachMapFromContainer,
  getMaplibre,
  scheduleMapResize
} from 'maplibre/turbo_map_host'

const FALLBACK_STYLE = 'https://demotiles.maplibre.org/style.json'

export default class extends Controller {
  static targets = ['canvas']
  static values = { payload: Object }

  connect () {
    this._markers = []
    this._mapHost = bindTurboMapHost({
      teardown: () => this._destroyMap(),
      getContainer: () => this.hasCanvasTarget ? this.canvasTarget : null,
      protectFromMorph: true,
      onMorph: () => this._onMorph()
    })
    this._buildMap()
  }

  disconnect () {
    if (this._mapHost) {
      this._mapHost.disconnect()
      this._mapHost = null
    } else {
      this._destroyMap()
    }
  }

  payloadValueChanged () {
    if (!this.map) return
    this._paint(this.payloadValue || {})
  }

  _onMorph () {
    const raw = this.element.getAttribute('data-delivery-tracking-map-payload-value')
    if (raw) {
      try { this.payloadValue = JSON.parse(raw) } catch (_) { /* keep previous */ }
    }
    if (!this.map) {
      this._buildMap()
      return
    }
    scheduleMapResize(this.map)
    this._paint(this.payloadValue || {})
  }

  _buildMap () {
    const maplibregl = getMaplibre()
    if (!maplibregl || !this.hasCanvasTarget) return
    const data = this.payloadValue || {}
    const dest = data.destination
    if (!dest) return

    this._destroyMap()

    const resolved = data.map_layers ? resolveMapStyle(data.map_layers) : null
    const style = resolved?.style || FALLBACK_STYLE

    const map = attachMapToContainer(this.canvasTarget, {
      style,
      center: [dest.lng, dest.lat],
      zoom: 12,
      interactive: false
    })
    if (!map) return
    this.map = map

    const onLoad = () => {
      this._paint(this._pendingPaint || data)
      scheduleMapResize(this.map)
    }
    if (this.map.isStyleLoaded()) onLoad()
    else this.map.once('load', onLoad)
  }

  _paint (data) {
    if (!this.map) return
    if (!this.map.isStyleLoaded()) {
      this._pendingPaint = data
      return
    }
    this._pendingPaint = null
    const dest = data.destination
    if (!dest || !Number.isFinite(Number(dest.lng)) || !Number.isFinite(Number(dest.lat))) return

    this._clearOverlays()

    const maplibregl = getMaplibre()
    if (!maplibregl) return

    const destLng = Number(dest.lng)
    const destLat = Number(dest.lat)
    const destMarker = new maplibregl.Marker({ color: '#1a365d' })
      .setLngLat([destLng, destLat])
      .addTo(this.map)
    this._markers.push(destMarker)

    const vehicle = data.vehicle
    if (vehicle && Number.isFinite(Number(vehicle.lng)) && Number.isFinite(Number(vehicle.lat))) {
      const vehicleLng = Number(vehicle.lng)
      const vehicleLat = Number(vehicle.lat)
      const wrap = document.createElement('div')
      wrap.className = 'operation-vehicle-pin-wrap'
      const halo = document.createElement('div')
      halo.className = 'operation-vehicle-accuracy'
      halo.setAttribute('aria-hidden', 'true')
      const pin = document.createElement('div')
      pin.className = 'operation-vehicle-pin'
      pin.innerHTML = '<i class="fa fa-truck" aria-hidden="true"></i>'
      wrap.append(halo, pin)
      const vehicleMarker = new maplibregl.Marker({ element: wrap, anchor: 'center' })
        .setLngLat([vehicleLng, vehicleLat])
        .addTo(this.map)
      this._markers.push(vehicleMarker)
      this._vehicleAccuracy = { el: halo, marker: vehicleMarker, meters: Number(vehicle.accuracy) }
    } else {
      this._vehicleAccuracy = null
    }

    this._paintTrack(Array.isArray(data.track) ? data.track : [])

    const bounds = new maplibregl.LngLatBounds([destLng, destLat], [destLng, destLat])
    if (this._vehicleAccuracy) {
      const { marker } = this._vehicleAccuracy
      const { lng, lat } = marker.getLngLat()
      bounds.extend([lng, lat])
      this._extendBoundsForAccuracy(bounds, { lng, lat, accuracy: this._vehicleAccuracy.meters })
    }
    ;(Array.isArray(data.track) ? data.track : []).forEach((c) => {
      if (Array.isArray(c) && c.length >= 2) bounds.extend([Number(c[0]), Number(c[1])])
    })
    this.map.fitBounds(bounds, { padding: 48, maxZoom: 14 })
    this.map.once('idle', () => this._syncVehicleAccuracySize())
    this._syncVehicleAccuracySize()
  }

  _paintTrack (track) {
    if (!this.map) return
    if (this.map.getLayer('track-line')) this.map.removeLayer('track-line')
    if (this.map.getSource('track')) this.map.removeSource('track')
    const coords = track
      .filter((c) => Array.isArray(c) && c.length >= 2)
      .map((c) => [Number(c[0]), Number(c[1])])
      .filter((c) => Number.isFinite(c[0]) && Number.isFinite(c[1]))
    if (coords.length < 2) return
    this.map.addSource('track', {
      type: 'geojson',
      data: { type: 'Feature', geometry: { type: 'LineString', coordinates: coords } }
    })
    this.map.addLayer({
      id: 'track-line',
      type: 'line',
      source: 'track',
      paint: { 'line-color': '#1a365d', 'line-width': 3, 'line-opacity': 0.55, 'line-dasharray': [2, 2] }
    })
  }

  _syncVehicleAccuracySize () {
    const state = this._vehicleAccuracy
    if (!state || !this.map) return
    const { el, marker, meters } = state
    if (!Number.isFinite(meters) || meters <= 0) {
      el.hidden = true
      return
    }
    const lat = marker.getLngLat().lat
    const zoom = this.map.getZoom()
    if (!Number.isFinite(zoom)) return
    const metersPerPixel = (156543.03392 * Math.cos((lat * Math.PI) / 180)) / (2 ** zoom)
    // Cap so a huge privacy halo cannot blow up the marker DOM / clip siblings.
    const canvas = this.hasCanvasTarget ? this.canvasTarget : null
    const maxDiameter = Math.max(64, (canvas?.clientWidth || 320) * 1.5)
    const diameter = Math.min(maxDiameter, Math.max(2, (2 * meters) / metersPerPixel))
    el.hidden = false
    el.style.width = `${diameter}px`
    el.style.height = `${diameter}px`
  }

  _extendBoundsForAccuracy (bounds, vehicle) {
    const radius = Number(vehicle.accuracy)
    if (!Number.isFinite(radius) || radius <= 0) return
    const latRad = (vehicle.lat * Math.PI) / 180
    const cos = Math.cos(latRad)
    if (!Number.isFinite(cos) || Math.abs(cos) < 1e-6) return
    const dLat = radius / 111_320
    const dLng = radius / (111_320 * cos)
    bounds.extend([vehicle.lng - dLng, vehicle.lat - dLat])
    bounds.extend([vehicle.lng + dLng, vehicle.lat + dLat])
  }

  _clearOverlays () {
    this._markers.forEach((marker) => marker.remove())
    this._markers = []
    this._vehicleAccuracy = null
    if (!this.map) return
    try {
      if (this.map.getLayer('track-line')) this.map.removeLayer('track-line')
      if (this.map.getSource('track')) this.map.removeSource('track')
    } catch (_) { /* style mid-switch */ }
  }

  _destroyMap () {
    this._clearOverlays()
    detachMapFromContainer(this.hasCanvasTarget ? this.canvasTarget : null)
    this.map = null
  }
}
