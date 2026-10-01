// Delivery tracking public map (MapLibre) — destination pin + optional approx vehicle / track
import { Controller } from '@hotwired/stimulus'
import { resolveMapStyle } from 'maplibre/raster_layers'

const FALLBACK_STYLE = 'https://demotiles.maplibre.org/style.json'

export default class extends Controller {
  static targets = ['canvas']
  static values = { payload: Object }

  connect () {
    this._markers = []
    this._afterMorph = () => this._onMorph()
    document.addEventListener('turbo:morph', this._afterMorph)
    this._buildMap()
  }

  disconnect () {
    document.removeEventListener('turbo:morph', this._afterMorph)
    this._destroyMap()
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
    this.map.resize()
    this._paint(this.payloadValue || {})
  }

  _buildMap () {
    if (!window.maplibregl || !this.hasCanvasTarget) return
    const data = this.payloadValue || {}
    const dest = data.destination
    if (!dest) return

    this._destroyMap()

    const resolved = data.map_layers ? resolveMapStyle(data.map_layers) : null
    const style = resolved?.style || FALLBACK_STYLE

    this.map = new window.maplibregl.Map({
      container: this.canvasTarget,
      style,
      center: [dest.lng, dest.lat],
      zoom: 12,
      interactive: false
    })

    this.map.on('load', () => {
      this._paint(this._pendingPaint || data)
      // Morph / layout can leave the WebGL canvas at 0×0 until resize.
      requestAnimationFrame(() => { if (this.map) this.map.resize() })
    })
  }

  _paint (data) {
    if (!this.map) return
    if (!this.map.isStyleLoaded()) {
      this._pendingPaint = data
      return
    }
    this._pendingPaint = null
    const dest = data.destination
    if (!dest) return

    this._clearOverlays()

    const destMarker = new window.maplibregl.Marker({ color: '#1a365d' })
      .setLngLat([dest.lng, dest.lat])
      .addTo(this.map)
    this._markers.push(destMarker)

    if (data.vehicle) {
      const el = document.createElement('div')
      el.className = 'delivery-tracking-vehicle-marker'
      const vehicleMarker = new window.maplibregl.Marker({ element: el })
        .setLngLat([data.vehicle.lng, data.vehicle.lat])
        .addTo(this.map)
      this._markers.push(vehicleMarker)
    }

    const track = Array.isArray(data.track) ? data.track : []
    if (track.length > 1) {
      this.map.addSource('track', {
        type: 'geojson',
        data: {
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: track.map((c) => [c[0], c[1]]) }
        }
      })
      this.map.addLayer({
        id: 'track-line',
        type: 'line',
        source: 'track',
        paint: { 'line-color': '#1a365d', 'line-width': 3, 'line-opacity': 0.55, 'line-dasharray': [2, 2] }
      })
    }

    const bounds = new window.maplibregl.LngLatBounds([dest.lng, dest.lat], [dest.lng, dest.lat])
    if (data.vehicle) bounds.extend([data.vehicle.lng, data.vehicle.lat])
    track.forEach((c) => bounds.extend([c[0], c[1]]))
    this.map.fitBounds(bounds, { padding: 48, maxZoom: 14 })
  }

  _clearOverlays () {
    this._markers.forEach((marker) => marker.remove())
    this._markers = []
    if (!this.map) return
    if (this.map.getLayer('track-line')) this.map.removeLayer('track-line')
    if (this.map.getSource('track')) this.map.removeSource('track')
  }

  _destroyMap () {
    this._clearOverlays()
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }
}
