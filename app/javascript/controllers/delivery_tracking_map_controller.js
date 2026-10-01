// Delivery tracking public map (MapLibre) — destination pin + optional approx vehicle / track
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

    this.map.on('load', () => {
      this._paint(this._pendingPaint || data)
      scheduleMapResize(this.map)
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

    const maplibregl = getMaplibre()
    if (!maplibregl) return

    const destMarker = new maplibregl.Marker({ color: '#1a365d' })
      .setLngLat([dest.lng, dest.lat])
      .addTo(this.map)
    this._markers.push(destMarker)

    if (data.vehicle) {
      const el = document.createElement('div')
      el.className = 'delivery-tracking-vehicle-marker'
      const vehicleMarker = new maplibregl.Marker({ element: el })
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

    const bounds = new maplibregl.LngLatBounds([dest.lng, dest.lat], [dest.lng, dest.lat])
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
    detachMapFromContainer(this.hasCanvasTarget ? this.canvasTarget : null)
    this.map = null
  }
}
