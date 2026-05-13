// Copyright © Cartoway
// V2 destinations index: MapLibre map (global from layout) + key:value search debounce.
// Vanilla DOM APIs only — no jQuery.

import { Controller } from '@hotwired/stimulus'
import { buildRasterStyle, pickLayers } from 'maplibre/raster_layers'
import { GeocoderIControl } from 'maplibre/geocoder_control'
import { BaseLayerSwitcherIControl } from 'maplibre/base_layer_switcher_control'
import { OverlayLayersToggleIControl } from 'maplibre/overlay_layers_toggle_control'

const DEFAULT_ZOOM = 12
const MIN_CHARS = 3
const DEBOUNCE_MS = 300

function getMaplibre () {
  return typeof window !== 'undefined' && window.maplibregl ? window.maplibregl : null
}

function createMarkerElement (active) {
  const el = document.createElement('div')
  el.className = 'destinations-v2-marker' + (active ? ' destinations-v2-marker--active' : '')
  el.setAttribute('role', 'button')
  return el
}

function parseKeyValueFilters (input) {
  if (!input || !input.includes(':')) return []
  const result = []
  input.split(/\s+/).forEach((part) => {
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
    this._markersById = {}
    this._iconOverStack = []
    this._searchDebounce = null

    const maplibregl = getMaplibre()
    const mapEl = this.element.querySelector('#map')
    if (maplibregl && mapEl && config.map_layers) {
      this._initMap(maplibregl, mapEl, config, signal)
    }

    this._initSearch(signal)

    document.addEventListener('turbo:before-cache', this._beforeCache, { signal })
    document.addEventListener('turbolinks:before-cache', this._beforeCache, { signal })
  }

  disconnect () {
    if (this._abort) this._abort.abort()
    this._abort = null
    this._teardownMap()
    this._map = null
  }

  _beforeCache = () => {
    this._teardownMap()
  }

  _teardownMap () {
    const mapEl = this.element.querySelector('#map')
    if (mapEl && mapEl._v2MaplibreMap) {
      try {
        mapEl._v2MaplibreMap.remove()
      } catch (e) { /* ignore */ }
      mapEl._v2MaplibreMap = null
    }
    Object.keys(this._markersById || {}).forEach((id) => {
      try {
        this._markersById[id].marker.remove()
      } catch (e) { /* ignore */ }
    })
    this._markersById = {}
    this._iconOverStack = []
  }

  _initMap (maplibregl, container, params, signal) {
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
      const placeholder = (typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.search') : 'Search'
      const emptyMsg = (typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.empty_result') : 'No results'
      map.addControl(new GeocoderIControl(placeholder, emptyMsg), 'top-right')
    }

    const basesOnly = pickLayers(params.map_layers).bases
    if (basesOnly.length > 1) {
      map.addControl(new BaseLayerSwitcherIControl(baseLayerIds, basesOnly), 'top-right')
    }

    if (overlayToggles && overlayToggles.length > 0) {
      const overlayTitle = params.map_overlay_title || 'Overlays'
      map.addControl(new OverlayLayersToggleIControl(overlayToggles, overlayTitle), 'top-right')
    }

    const markersById = {}
    this._markersById = markersById
    const iconOverStack = this._iconOverStack

    const clearHighlight = () => {
      this.element.querySelectorAll('tr.destination').forEach((tr) => tr.classList.remove('highlight'))
      while (iconOverStack.length) {
        const id = iconOverStack.pop()
        const m = markersById[id]
        if (m) m.el.classList.remove('destinations-v2-marker--active')
      }
    }

    const over = (id, scrollRow) => {
      if (iconOverStack.indexOf(id) !== -1) return
      clearHighlight()
      const m = markersById[id]
      if (m) {
        m.el.classList.add('destinations-v2-marker--active')
        iconOverStack.push(id)
        if (scrollRow) {
          map.flyTo({ center: m.marker.getLngLat(), zoom: Math.max(map.getZoom(), 14), duration: 500 })
        }
      }
      const row = Array.from(this.element.querySelectorAll('tr.destination')).find((tr) => tr.getAttribute('data-destination-id') === id)
      if (row) {
        row.classList.add('highlight')
        const box = this.element.querySelector('#destination_box')
        if (box) row.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
      }
    }

    ;(params.destinations || []).forEach((d) => {
      if (d.lat == null || d.lng == null) return
      const el = createMarkerElement(false)
      const marker = new maplibregl.Marker({ element: el, anchor: 'bottom' })
        .setLngLat([d.lng, d.lat])
        .addTo(map)
      el.addEventListener('click', (e) => {
        e.stopPropagation()
        over(String(d.id), false)
      })
      markersById[String(d.id)] = { marker, el, lngLat: [d.lng, d.lat] }
    })

    const coords = Object.keys(markersById).map((id) => markersById[id].lngLat)
    if (coords.length > 0) {
      const bounds = new maplibregl.LngLatBounds(coords[0], coords[0])
      coords.forEach((c) => bounds.extend(c))
      map.fitBounds(bounds, { padding: 48, maxZoom: 15, duration: 0 })
    }

    this.element.addEventListener('click', (e) => {
      const tr = e.target.closest && e.target.closest('tr.destination[data-destination-id]')
      if (!tr) return
      const id = tr.getAttribute('data-destination-id')
      if (id && markersById[id]) over(id, false)
    }, { signal })

    const sidebar = this.element.querySelector('.destinations-sidebar')
    const scheduleResize = () => { setTimeout(() => map.resize(), 220) }
    const toggleBtn = this.element.querySelector('.destinations-sidebar-toggle')
    const expandBtn = this.element.querySelector('.destinations-sidebar-expand button')
    if (toggleBtn) {
      toggleBtn.addEventListener('click', () => {
        if (sidebar) sidebar.classList.add('collapsed')
        scheduleResize()
      }, { signal })
    }
    if (expandBtn) {
      expandBtn.addEventListener('click', () => {
        if (sidebar) sidebar.classList.remove('collapsed')
        scheduleResize()
      }, { signal })
    }

    map.once('load', () => { map.resize() })
  }

  _initSearch (signal) {
    const form = this.element.querySelector('#destinations-search-form')
    const input = this.element.querySelector('#search-query')
    if (!form || !input) return

    const submitForm = (additionalFilters = []) => {
      if (additionalFilters.length) {
        additionalFilters.forEach((raw) => {
          const field = document.createElement('input')
          field.type = 'hidden'
          field.name = 'filters[]'
          field.value = raw
          form.appendChild(field)
        })
        input.value = ''
      }
      form.submit()
    }

    input.addEventListener('input', () => {
      clearTimeout(this._searchDebounce)
      this._searchDebounce = setTimeout(() => {
        this._searchDebounce = null
        if (!hasMinCharsForSearch(input.value)) return
        submitForm()
      }, DEBOUNCE_MS)
    }, { signal })

    input.addEventListener('keydown', (e) => {
      if (e.key !== 'Enter') return
      e.preventDefault()
      const val = input.value.trim()
      const filters = parseKeyValueFilters(val)
      if (filters.length) submitForm(filters.map((f) => f.raw))
      else if (hasMinCharsForSearch(val)) submitForm()
    }, { signal })
  }
}
