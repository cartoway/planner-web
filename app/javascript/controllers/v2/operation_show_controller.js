import { Controller } from '@hotwired/stimulus'
import { connectStreamSource, disconnectStreamSource } from '@hotwired/turbo'
import { TeritorioCluster } from '@teritorio/maplibre-gl-teritorio-cluster'
import { fillClusterMarker, fillDestinationMarker } from 'maplibre/destination_markers'
import { pickLayers, resolveMapStyle, styleForBaseLayer, basesNeedStyleSwitch, applyOverlays } from 'maplibre/raster_layers'
import { OverlayLayersToggleIControl } from 'maplibre/overlay_layers_toggle_control'
import { GeocoderIControl } from 'maplibre/geocoder_control'
import { disableMapPitchAndRotation } from 'maplibre/map_interactions'
import { DeclusterViewportIControl } from 'maplibre/decluster_viewport_control'
import { attachMapToContainer, bindTurboMapHost, detachMapFromContainer, getMaplibre } from 'maplibre/turbo_map_host'

const OPACITY_MIN = 0.4
const OPACITY_MAX = 1
const OPERATION_LINES_LAYER_ID = 'operation-lines'
const OPERATION_STOPS_SOURCE_ID = 'operation-stops'
const OPERATION_STOPS_LAYER_ID = 'operation-stops-clusters'
const OPERATION_STOPS_OPEN_SOURCE_ID = 'operation-stops-open'
const OPERATION_STOPS_OPEN_LAYER_ID = 'operation-stops-open-markers'
const PHASE_COLORS = {
  delivered: '#1f9d55',
  failed: '#d64545',
  exception: '#7c3aed',
  current: '#25417c',
  late: '#f59e0b',
  upcoming: '#9ca3af'
}

export default class extends Controller {
  static targets = ['map', 'list', 'more', 'stopQuery', 'nameLabel', 'nameInput']
  static values = { mapUrl: String, searchUrl: String, positionsUrl: String }

  connect () {
    this.selectedRouteId = null
    this._hiddenRouteIds = new Set()
    this._excludedRouteIds = new Set()
    this.phase = 'all'
    this.query = ''
    this._restorePersistedRouteSelection()
    this._beforeMorph = (event) => this._keepLiveState(event)
    document.addEventListener('turbo:before-morph-element', this._beforeMorph, true)
    this._mapHost = bindTurboMapHost({
      teardown: () => this._teardownMap(),
      getContainer: () => this.hasMapTarget ? this.mapTarget : null,
      protectFromMorph: true,
      onMorph: () => this._refreshLive()
    })
    this._bindTours()
    this._bindListScroll()
    const open = this.element.querySelector('details.operation-tour[open]')
    if (open) this._focusRoute(open)
    this._syncRouteSelectionUi()
    this._loadMap()
  }

  editName (event) {
    event.preventDefault()
    this.nameLabelTarget.classList.add('d-none')
    event.currentTarget.classList.add('d-none')
    this.nameInputTarget.classList.remove('d-none')
    this.nameInputTarget.focus()
  }

  saveNameOnEnter (event) {
    if (event.key !== 'Enter') return
    event.preventDefault()
    this.saveName(event)
  }

  saveName (event) {
    this._saveField(event.currentTarget, 'name', (data) => {
      if (!data || !data.name) return
      this.nameLabelTarget.textContent = data.name
      this.nameLabelTarget.classList.remove('d-none')
      this.nameInputTarget.classList.add('d-none')
      this.nameInputTarget.previousElementSibling.classList.remove('d-none')
    })
  }

  saveDate (event) {
    const input = event.currentTarget
    this._saveField(input, 'date', (data) => {
      if (data && data.date) input.defaultValue = data.date
    })
  }

  async _saveField (input, key, done) {
    const token = input.form.querySelector('[name=authenticity_token]').value
    const body = new URLSearchParams()
    body.append('_method', 'patch')
    body.append('authenticity_token', token)
    body.append(`operation[${key}]`, input.value)
    const response = await fetch(input.form.action, {
      method: 'POST',
      headers: { Accept: 'application/json' },
      body
    })
    const data = await response.json()
    if (!response.ok) {
      if (data && data.error) window.alert(data.error)
      if (key === 'date') input.value = input.defaultValue
      return
    }
    done(data)
  }

  _bindTours () {
    this.element.addEventListener('exclusive-accordion:open', (event) => {
      const details = event.target
      if (!details.classList || !details.classList.contains('operation-tour')) return
      this._focusRoute(details)
      this._applyFilters()
    })
    this.element.addEventListener('exclusive-accordion:close-all', () => {
      this.selectedRouteId = null
      this._paint()
      this._addVehicleMarker()
    })
  }

  filterPhase (event) {
    this.phase = event.currentTarget.dataset.phase || 'all'
    this.element.querySelectorAll('.operation-chip').forEach((chip) => {
      chip.classList.toggle('is-active', chip === event.currentTarget)
    })
    this._applyFilters()
  }

  filterQuery (event) {
    this.query = event.currentTarget.value.trim().toLowerCase()
    this._applyFilters()
  }

  _applyFilters () {
    this.element.querySelectorAll('details.operation-tour .operation-stop-row').forEach((row) => {
      const phase = row.dataset.phase
      const label = (row.dataset.label || row.textContent || '').toLowerCase()
      const phaseOk = this.phase === 'all' || phase === 'depot' || phase === this.phase
      const queryOk = !this.query || label.includes(this.query)
      row.classList.toggle('is-hidden', !(phaseOk && queryOk))
    })
  }

  _focusRoute (details) {
    const routeId = details.dataset.routeId
    this.selectedRouteId = routeId
    this._paint()
    this._addVehicleMarker()
  }

  selectDepot (event) {
    if (event.target.closest('a, button')) return
    const row = event.currentTarget
    this._openDetail()
    this.element.querySelectorAll('.operation-stop-row.is-selected').forEach((item) => item.classList.remove('is-selected'))
    row.classList.add('is-selected')
    const body = document.getElementById('operation-detail-body')
    if (!body) return
    body.replaceChildren(this._depotFiche(row.dataset))
    this._centerRow(row)
  }

  _depotFiche (data) {
    const labels = this.element.dataset
    const root = document.createElement('div')
    root.className = 'operation-fiche operation-stop-detail'

    const head = document.createElement('div')
    head.className = 'd-flex align-items-start justify-content-between gap-2'
    const titleWrap = document.createElement('div')
    const title = document.createElement('h2')
    title.className = 'mb-0'
    title.textContent = data.name || data.role || ''
    titleWrap.appendChild(title)
    if (data.role) {
      const role = document.createElement('p')
      role.className = 'small text-muted mb-0'
      role.textContent = data.role
      titleWrap.appendChild(role)
    }
    head.appendChild(titleWrap)
    if (data.statusLabel) {
      const badge = document.createElement('span')
      badge.className = 'badge operation-status'
      badge.textContent = data.statusLabel
      head.appendChild(badge)
    }
    root.appendChild(head)

    const split = document.createElement('div')
    split.className = 'operation-split'
    split.appendChild(this._splitCell(labels.plannedLabel || '', data.time || '—'))
    split.appendChild(this._splitCell(labels.statusLabel || '', data.statusLabel || '—'))
    root.appendChild(split)

    if (data.ref) {
      const details = this._section(labels.refLabel || '')
      const ref = document.createElement('p')
      ref.className = 'small mb-0'
      ref.textContent = data.ref
      details.appendChild(ref)
      root.appendChild(details)
    }

    const address = this._section(labels.addressLabel || '')
    const field = document.createElement('div')
    field.className = 'operation-field'
    const line = document.createElement('p')
    line.className = data.phone ? 'mb-1' : 'mb-0'
    line.textContent = data.address || '—'
    field.appendChild(line)
    if (data.phone) {
      const phone = document.createElement('p')
      phone.className = 'mb-0'
      const icon = document.createElement('i')
      icon.className = 'fa fa-phone fa-fw'
      icon.setAttribute('aria-hidden', 'true')
      const link = document.createElement('a')
      link.href = `tel:${data.phone}`
      link.textContent = data.phone
      phone.append(icon, link)
      field.appendChild(phone)
    }
    address.appendChild(field)
    root.appendChild(address)
    return root
  }

  _section (title) {
    const section = document.createElement('section')
    section.className = 'operation-section'
    const heading = document.createElement('h3')
    heading.textContent = title
    section.appendChild(heading)
    return section
  }

  _splitCell (label, value) {
    const cell = document.createElement('div')
    const caption = document.createElement('span')
    caption.textContent = label
    const strong = document.createElement('strong')
    strong.textContent = value
    cell.append(caption, strong)
    return cell
  }

  _openDetail () {
    const panel = document.getElementById('operation-detail')
    if (panel) panel.classList.add('is-open')
    this._compactAttribution()
  }

  // Collapse the OSM attribution when the right panel steals map width.
  _compactAttribution () {
    const attrib = this.mapTarget?.querySelector('.maplibregl-ctrl-attrib.maplibregl-compact-show')
    if (!attrib) return
    attrib.classList.remove('maplibregl-compact-show')
    attrib.setAttribute('open', '')
  }

  _centerRow (row) {
    const lng = parseFloat(row.dataset.lng)
    const lat = parseFloat(row.dataset.lat)
    if (!Number.isFinite(lng) || !Number.isFinite(lat)) return
    this._pendingCenter = { lng, lat, stopId: row.dataset.stopId }
    requestAnimationFrame(() => {
      this._flyToStop(this._pendingCenter)
      this._resizeMap()
    })
  }

  async selectStop (event) {
    if (event.target.closest('a, button')) return
    const row = event.currentTarget
    if (!row.dataset.stopId) return
    this.element.querySelectorAll('.operation-stop-row.is-selected').forEach((item) => item.classList.remove('is-selected'))
    row.classList.add('is-selected')
    this._openDetail()
    const body = document.getElementById('operation-detail-body')
    const response = await fetch(row.dataset.url, { headers: { Accept: 'text/html' } })
    if (response.ok && body) {
      const doc = new DOMParser().parseFromString(await response.text(), 'text/html')
      const fiche = doc.querySelector('.operation-stop-detail')
      if (fiche) body.replaceChildren(fiche)
    }
    this._centerRow(row)
  }

  closeDetail () {
    const panel = document.getElementById('operation-detail')
    if (panel) panel.classList.remove('is-open')
    this.element.querySelectorAll('.operation-stop-row.is-selected').forEach((item) => item.classList.remove('is-selected'))
    this._activeStopId = null
    this._paintActiveStop()
    this._resizeMap()
  }

  _bindSidebar () {
    const sidebar = this.element.querySelector('.destinations-sidebar')
    this.element.addEventListener('click', (event) => {
      if (event.target.closest('.destinations-sidebar-toggle')) {
        sidebar?.classList.add('slide-panel--collapsed')
        this._resizeMap()
      } else if (event.target.closest('.destinations-sidebar-expand')) {
        sidebar?.classList.remove('slide-panel--collapsed')
        this._resizeMap()
      }
    })
  }

  _resizeMap () {
    window.setTimeout(() => { if (this.map) this.map.resize() }, 240)
  }

  scrollListTop () {
    this._listScroller()?.scrollTo({ top: 0, behavior: 'smooth' })
  }

  _listScroller () {
    return this.element.querySelector('.operation-list-body')
  }

  _bindListScroll () {
    const list = this._listScroller()
    if (!list) return
    this._onListScroll = () => {
      const button = this.element.querySelector('.operation-scroll-top')
      if (button) button.classList.toggle('is-visible', list.scrollTop > 0)
    }
    list.addEventListener('scroll', this._onListScroll, { passive: true })
  }

  disconnect () {
    const list = this._listScroller()
    if (list && this._onListScroll) list.removeEventListener('scroll', this._onListScroll)
    document.removeEventListener('turbo:before-morph-element', this._beforeMorph, true)
    if (this._mapHost) {
      this._mapHost.disconnect()
      this._mapHost = null
    } else {
      this._teardownMap()
    }
  }

  _teardownMap () {
    this._clearStopMarkers()
    if (this._vehicleMarker) {
      this._vehicleMarker.remove()
      this._vehicleMarker = null
    }
    if (this.map && this._onMapMoveEnd) {
      try { this.map.off('moveend', this._onMapMoveEnd) } catch (_) { /* ignore */ }
    }
    detachMapFromContainer(this.hasMapTarget ? this.mapTarget : null)
    this.map = null
  }

  _keepLiveState (event) {
    const current = event.target
    const next = event.detail && event.detail.newElement
    if (!(current instanceof Element) || !next) return
    if (current.classList.contains('operation-tour')) next.open = current.open
    if (current.classList.contains('operation-stop-row') || current.classList.contains('operation-depot-row')) {
      next.classList.toggle('is-selected', current.classList.contains('is-selected'))
    }
    if (current.classList.contains('operation-chip')) {
      next.classList.toggle('is-active', current.classList.contains('is-active'))
    }
    if (current.matches('.operation-route-selector-option input[type="checkbox"]')) {
      // Server HTML always ships checked:true; keep the live selector across demo ticks.
      next.checked = current.checked
    }
    if (current.matches('.operation-route-toolbar input[type="search"]')) {
      next.value = current.value
    }
    if (current.id === 'operation-detail') {
      next.className = current.className
      next.innerHTML = current.innerHTML
    }
  }

  _refreshLive () {
    const open = this.element.querySelector('details.operation-tour[open]')
    if (open) this._focusRoute(open)
    this._syncRouteSelectionUi()
    this._applyFilters()
    this._recolorMarkers()
    this._refreshGeojson()
    this._reloadSelectedFiche()
  }

  _recolorMarkers () {
    const phases = new Map()
    this.element.querySelectorAll('.operation-stop-row').forEach((row) => {
      if (row.dataset.stopId) phases.set(row.dataset.stopId, row.dataset.phase)
    })
    ;(this.geojson?.features || []).forEach((feature) => {
      const stopId = feature.properties && feature.properties.operation_stop_id
      const phase = stopId != null && phases.get(String(stopId))
      if (phase && feature.properties) feature.properties.phase = phase
    })
    this._syncStopClusters()
  }

  _paintMarker (element, phase) {
    const color = PHASE_COLORS[phase]
    if (color) element.style.setProperty('--dm-flat', color)
  }

  async _refreshGeojson () {
    if (!this.map || !this.map.getSource('operation')) {
      this._geojsonStale = true
      return
    }
    const response = await fetch(this.mapUrlValue, { cache: 'no-store', headers: { Accept: 'application/json' } })
    if (!response.ok) return
    this.geojson = await response.json()
    this._geojsonStale = false
    this.map.getSource('operation').setData(this.geojson)
    this._syncStopClusters()
    this._addVehicleMarker()
    this._applyRouteVisibility()
    this._paint()
    this._syncVehicleButtons()
  }

  async _reloadSelectedFiche () {
    const row = this.element.querySelector('.operation-stop-row.is-selected')
    const body = document.getElementById('operation-detail-body')
    if (!row || !row.dataset.url || !body) return
    const response = await fetch(row.dataset.url, { headers: { Accept: 'text/html' } })
    if (!response.ok) return
    const doc = new DOMParser().parseFromString(await response.text(), 'text/html')
    const fiche = doc.querySelector('.operation-stop-detail')
    if (fiche) body.replaceChildren(fiche)
  }

  async openMedia (event) {
    event.preventDefault()
    event.stopPropagation()
    const link = event.currentTarget
    const url = new URL(link.href, window.location.origin)
    url.searchParams.set('modal', '1')
    const response = await fetch(url, { headers: { Accept: 'text/html' } })
    if (!response.ok) return
    let host = document.getElementById('operation-media-host')
    if (!host) {
      host = document.createElement('div')
      host.id = 'operation-media-host'
      document.body.appendChild(host)
    }
    host.innerHTML = await response.text()
    const modal = host.querySelector('.modal')
    if (!modal || !window.bootstrap?.Modal) return
    this._bindMediaModal(modal)
    window.bootstrap.Modal.getOrCreateInstance(modal).show()
  }

  _bindMediaModal (modal) {
    if (modal.dataset.mediaBound) return
    modal.dataset.mediaBound = '1'
    const track = modal.querySelector('[data-media-track]')
    const prev = modal.querySelector('[data-media-prev]')
    const next = modal.querySelector('[data-media-next]')
    const step = (direction) => {
      if (!track) return
      const card = track.querySelector('[data-media-group]')
      if (!card) return
      const gap = parseFloat(getComputedStyle(track).columnGap || getComputedStyle(track).gap) || 12
      const delta = card.getBoundingClientRect().width + gap
      const max = track.scrollWidth - track.clientWidth
      if (direction > 0 && track.scrollLeft >= max - 4) track.scrollTo({ left: 0, behavior: 'smooth' })
      else if (direction < 0 && track.scrollLeft <= 4) track.scrollTo({ left: max, behavior: 'smooth' })
      else track.scrollBy({ left: direction * delta, behavior: 'smooth' })
    }
    prev?.addEventListener('click', () => step(-1))
    next?.addEventListener('click', () => step(1))
  }

  centerStop (event) {
    const button = event.currentTarget
    const lng = parseFloat(button.dataset.lng)
    const lat = parseFloat(button.dataset.lat)
    if (!Number.isFinite(lng) || !Number.isFinite(lat)) return
    const opensForm = button.dataset.turboFrame === 'form_sidebar'
    this._pendingCenter = { lng, lat, stopId: button.dataset.stopId }
    this._flyToStop(this._pendingCenter)
    if (!opensForm) return
    const refresh = () => this._flyToStop(this._pendingCenter)
    document.addEventListener('turbo:frame-load', function onFrame (frameEvent) {
      if (!frameEvent.target || frameEvent.target.id !== 'form_sidebar') return
      document.removeEventListener('turbo:frame-load', onFrame)
      window.setTimeout(refresh, 260)
    })
  }

  toggleRoute (event) {
    event.preventDefault()
    event.stopPropagation()
    const button = event.currentTarget
    const route = button.closest('li.route')
    const stops = route.querySelector('ul.stops')
    const icon = button.querySelector('i')
    const hidden = !stops.classList.contains('d-none')
    stops.classList.toggle('d-none', hidden)
    icon.classList.toggle('fa-eye', !hidden)
    icon.classList.toggle('fa-eye-slash', hidden)
    this._hiddenRouteIds = this._hiddenRouteIds || new Set()
    const id = String(route.dataset.routeId)
    if (hidden) this._hiddenRouteIds.add(id)
    else this._hiddenRouteIds.delete(id)
    this._applyRouteVisibility()
  }

  selectRoute (event) {
    const row = event.target.closest('[data-route-id]')
    if (!row) return
    this.selectedRouteId = row.dataset.routeId
    this.element.querySelectorAll('li.route').forEach((item) => item.classList.toggle('is-selected', item === row))
    this._paint()
  }

  toggleSidebar (event) {
    event.preventDefault()
    const sidebar = this.element.querySelector('#edit-planning')
    if (sidebar) sidebar.classList.toggle('collapsed')
    if (this.map) this.map.resize()
  }

  async searchStops () {
    const q = this.hasStopQueryTarget ? this.stopQueryTarget.value : ''
    if (!q) return
    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set('q', q)
    const response = await fetch(url, { headers: { Accept: 'application/json' } })
    if (!response.ok) return
    const stops = await response.json()
    const box = this.element.querySelector('#operation-stop-results')
    if (!box) return
    box.innerHTML = stops.map((stop) => `<button type="button" class="list-group-item list-group-item-action" data-stop-id="${stop.id}" data-route-id="${stop.operation_route_id}">${stop.index} ${stop.label}</button>`).join('')
    box.querySelectorAll('button').forEach((button) => {
      button.addEventListener('click', () => {
        this.selectedRouteId = button.dataset.routeId
        const row = document.getElementById(`stop-${button.dataset.stopId}`)
        if (row) row.scrollIntoView({ block: 'center' })
        this._paint()
      })
    })
  }

  async loadMore (event) {
    event.preventDefault()
    const link = event.currentTarget
    const response = await fetch(link.href, { headers: { Accept: 'text/html' } })
    if (!response.ok) return
    const html = await response.text()
    link.insertAdjacentHTML('beforebegin', html)
    link.remove()
    this.applyRouteSelection()
    this._syncVehicleButtons()
  }

  filterRouteSelector (event) {
    this._routeSelectorFilter = event.currentTarget.value
    this._applyRouteSelectorFilter(this._routeSelectorFilter)
    this._persistRouteSelection()
  }

  clearRouteSelectorFilter (event) {
    event.preventDefault()
    event.stopPropagation()
    const input = this.element.querySelector('.operation-route-toolbar input[type="search"]')
    if (input) input.value = ''
    this._routeSelectorFilter = ''
    this._applyRouteSelectorFilter('')
    this._persistRouteSelection()
  }

  _applyRouteSelectorFilter (raw) {
    const query = (raw || '').trim().toLowerCase()
    this.element.querySelectorAll('.operation-route-selector-option').forEach((option) => {
      const label = option.dataset.filterLabel || ''
      option.hidden = query.length > 0 && !label.includes(query)
    })
    const clear = this.element.querySelector('.operation-route-selector-clear')
    if (clear) clear.classList.toggle('d-none', query.length === 0)
  }

  selectRoutes (event) {
    event.preventDefault()
    const mode = event.currentTarget.dataset.mode
    // An active search only toggles the tours still listed.
    this._routeCheckboxes().filter((box) => {
      const option = box.closest('.operation-route-selector-option')
      return !option || !option.hidden
    }).forEach((box) => {
      if (mode === 'all') box.checked = true
      else if (mode === 'clear') box.checked = false
      else box.checked = !box.checked
    })
    this.applyRouteSelection()
  }

  applyRouteSelection () {
    const boxes = this._routeCheckboxes()
    const excluded = new Set()
    boxes.forEach((box) => {
      if (!box.checked) excluded.add(String(box.value))
    })
    this._excludedRouteIds = excluded
    this._persistRouteSelection()
    this._applyExcludedRoutes()
    this._syncRouteSelectorLabel(boxes.length - excluded.size)
    this._applyRouteVisibility()
    this._addVehicleMarker()
  }

  _syncRouteSelectionUi () {
    const excluded = this._excludedRouteIds || new Set()
    this._routeCheckboxes().forEach((box) => {
      box.checked = !excluded.has(String(box.value))
    })
    const input = this.element.querySelector('.operation-route-toolbar input[type="search"]')
    if (input && this._routeSelectorFilter != null) {
      input.value = this._routeSelectorFilter
      this._applyRouteSelectorFilter(this._routeSelectorFilter)
    }
    this._applyExcludedRoutes()
    this._syncRouteSelectorLabel(this._routeCheckboxes().length - excluded.size)
    this._syncTraceButtons()
    this._applyRouteVisibility()
    this._addVehicleMarker()
  }

  _applyExcludedRoutes () {
    const excluded = this._excludedRouteIds || new Set()
    this.element.querySelectorAll('details.operation-tour').forEach((tour) => {
      tour.hidden = excluded.has(String(tour.dataset.routeId))
    })
    this.element.querySelectorAll('section.operation-group').forEach((section) => {
      const tours = [...section.querySelectorAll('details.operation-tour')]
      section.hidden = tours.length > 0 && tours.every((tour) => tour.hidden)
    })
  }

  _selectionStorageKey () {
    return `operation-route-selection:${window.location.pathname}`
  }

  _persistRouteSelection () {
    const input = this.element.querySelector('.operation-route-toolbar input[type="search"]')
    this._routeSelectorFilter = input ? input.value : (this._routeSelectorFilter || '')
    try {
      sessionStorage.setItem(this._selectionStorageKey(), JSON.stringify({
        excluded: [...(this._excludedRouteIds || [])],
        hidden: [...(this._hiddenRouteIds || [])],
        filter: this._routeSelectorFilter
      }))
    } catch (_) {}
  }

  _restorePersistedRouteSelection () {
    try {
      const raw = sessionStorage.getItem(this._selectionStorageKey())
      if (!raw) return
      const data = JSON.parse(raw)
      this._excludedRouteIds = new Set((data.excluded || []).map(String))
      this._hiddenRouteIds = new Set((data.hidden || []).map(String))
      this._routeSelectorFilter = data.filter || ''
    } catch (_) {}
  }

  async _loadMap () {
    const maplibregl = getMaplibre()
    if (!maplibregl || !this.hasMapTarget) return
    const response = await fetch(this.mapUrlValue, { cache: 'no-store', headers: { Accept: 'application/json' } })
    if (!response.ok) return
    this.geojson = await response.json()

    let params = {}
    try { params = JSON.parse(this.element.getAttribute('data-config') || '{}') } catch (e) { params = {} }
    this._mapParams = params

    const mapLayers = params.map_layers || {}
    const resolved = resolveMapStyle(mapLayers)
    const { style, baseLayerIds, overlayToggles } = resolved
    const center = this._center()
    const zoom = params.map_zoom != null ? Number(params.map_zoom) : 12

    const map = attachMapToContainer(this.mapTarget, {
      style,
      center,
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
    this.map = map
    disableMapPitchAndRotation(this.map)
    this.map.on('style.load', () => disableMapPitchAndRotation(this.map))

    this._stopsDeclustered = false
    const tDecluster = (typeof I18n !== 'undefined' && I18n.t)
      ? I18n.t('destinations.index.map_decluster_viewport')
      : 'Déclusteriser la vue'
    const tRecluster = (typeof I18n !== 'undefined' && I18n.t)
      ? I18n.t('destinations.index.map_recluster_viewport')
      : 'Clusteriser la vue'
    this.map.addControl(new DeclusterViewportIControl({
      getDeclustered: () => !!this._stopsDeclustered,
      onToggle: (declustered) => {
        this._stopsDeclustered = declustered
        this._syncStopClusters()
      },
      titleDecluster: tDecluster,
      titleRecluster: tRecluster
    }), 'top-right')
    this._onMapMoveEnd = () => {
      if (this._stopsDeclustered) this._syncStopClusters()
    }
    this.map.on('moveend', this._onMapMoveEnd)
    this.map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right')
    this.map.addControl(new maplibregl.ScaleControl({ maxWidth: 120, unit: 'metric' }), 'bottom-left')

    if (params.geocoder) {
      const placeholder = params.geocoder_placeholder ||
        ((typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.search') : 'Search an address...')
      const emptyMsg = params.geocoder_empty ||
        ((typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.empty_result') : 'No results found')
      const tooltip = params.geocoder_tooltip ||
        ((typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.tooltip') : placeholder)
      const submitLabel = params.geocoder_submit ||
        ((typeof I18n !== 'undefined' && I18n.t) ? I18n.t('web.geocoder.submit_search') : 'Search')
      this.map.addControl(new GeocoderIControl(placeholder, emptyMsg, { tooltip, submitLabel }), 'top-right')
    }

    const { bases: basesOnly, overlays: overlayLayers } = pickLayers(mapLayers)
    this._mapOverlayLayers = overlayLayers
    this._overlayToggles = overlayToggles || []
    this._overlayVisibility = {}
    this._overlayToggles.forEach((t) => {
      this._overlayVisibility[t.layerId] = !!t.initialVisible
    })
    this._mapStyleMode = resolved.mode
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
      this.map.addControl(new OverlayLayersToggleIControl(this._overlayToggles, layersTitle, {
        bases: baseSpecs,
        baseSectionTitle: params.map_base_layers_title || '',
        overlaySectionTitle: params.map_overlay_title || '',
        onBaseChange: useStyleSwitch ? (spec) => this._switchBaseLayer(spec) : null
      }), 'top-right')
    }

    const onLoad = () => {
      this._mountOperationLayers()
      this._applyOverlays({ includeRaster: this._mapStyleMode === 'vector' })
      if (this._geojsonStale) this._refreshGeojson()
      if (this._pendingCenter) this._flyToStop(this._pendingCenter)
      else if (this._pendingLocateRouteId) this._locateRoute(this._pendingLocateRouteId)
      else if (this._pendingFitRouteId) this._fitRoute(this._pendingFitRouteId)
      else this._fit()
      this._syncVehicleButtons()
      this.map.resize()
    }
    // Inline / cached styles can emit load before we subscribe.
    if (this.map.isStyleLoaded()) onLoad()
    else this.map.once('load', onLoad)
  }

  _mountOperationLayers () {
    if (!this.map || this.map.getSource('operation')) return
    this.map.addSource('operation', { type: 'geojson', data: this.geojson || { type: 'FeatureCollection', features: [] }, tolerance: 0 })
    this.map.addLayer({
      id: OPERATION_LINES_LAYER_ID,
      type: 'line',
      source: 'operation',
      filter: ['==', ['geometry-type'], 'LineString'],
      paint: {
        'line-color': ['coalesce', ['get', 'color'], '#3366cc'],
        'line-width': ['case', ['==', ['get', 'geometry_kind'], 'positions'], 4, 3],
        'line-dasharray': ['case', ['==', ['get', 'geometry_kind'], 'positions'], ['literal', [1.5, 1.5]], ['literal', [1, 0]]],
        'line-opacity': ['coalesce', ['get', 'opacity'], OPACITY_MAX]
      }
    })
    this._syncStopClusters()
    this._addVehicleMarker()
    this._applyRouteVisibility()
    this._paint()
  }

  _applyOverlays ({ includeRaster } = {}) {
    const overlays = this._mapOverlayLayers || []
    if (!overlays.length) return
    if (!includeRaster && !overlays.some((o) => o.vectorStyleUrl)) return
    this._syncOverlayVisibilityFromControl()
    applyOverlays(
      this.map,
      overlays,
      this._overlayVisibility,
      this._overlayToggles,
      { includeRaster: includeRaster !== false, beforeId: OPERATION_LINES_LAYER_ID }
    ).catch(() => { /* overlay style fetch failed */ })
  }

  _switchBaseLayer (spec) {
    if (!this.map || !spec) return
    const nextStyle = styleForBaseLayer(spec)
    if (!nextStyle) return
    this._syncOverlayVisibilityFromControl()
    this._clearStopMarkers()
    if (this._vehicleMarker) {
      this._vehicleMarker.remove()
      this._vehicleMarker = null
    }
    const switchId = (this._baseSwitchId = (this._baseSwitchId || 0) + 1)
    const reattach = () => {
      if (switchId !== this._baseSwitchId || !this.map) return
      if (this.map.getSource('operation')) return
      this._mountOperationLayers()
      this._applyOverlays({ includeRaster: true })
    }
    this.map.once('style.load', reattach)
    this.map.setStyle(nextStyle, { diff: false })
    requestAnimationFrame(() => {
      if (this.map && this.map.isStyleLoaded()) reattach()
    })
    this.map.once('idle', reattach)
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

  centerVehicle (event) {
    event.preventDefault()
    const routeId = event.currentTarget.dataset.routeId
    if (!routeId || !this._vehiclePosition(routeId)) return
    this._revealRoute(routeId)
    this._openRoute(routeId)
    this._pendingLocateRouteId = routeId
    if (this.map && this.geojson) this._locateRoute(routeId)
  }

  centerRoute (event) {
    event.preventDefault()
    event.stopPropagation()
    const routeId = event.currentTarget.dataset.routeId
    if (!routeId) return
    const revealed = this._revealRoute(routeId)
    this._openRoute(routeId)
    this._pendingFitRouteId = routeId
    this._fitRoute(routeId, revealed)
  }

  openRouteSend (event) {
    event.preventDefault()
    event.stopPropagation()
    const button = event.currentTarget
    const modal = document.getElementById('operation-route-send')
    if (!modal || !window.bootstrap) return
    const channel = button.dataset.channel === 'sms' ? 'sms' : 'email'
    modal.querySelector('[data-route-send-channel]').value = channel
    const input = modal.querySelector('[data-route-send-input]')
    input.value = button.dataset.contact || ''
    input.name = `routes[${button.dataset.routeId}][${button.dataset.field}]`
    const flag = modal.querySelector('[data-route-send-flag]')
    flag.name = `routes[${button.dataset.routeId}][send]`
    flag.value = '1'
    modal.querySelector('[data-route-send-title]').textContent = modal.dataset[`${channel}Title`] || ''
    modal.querySelector('[data-route-send-label]').textContent = modal.dataset[`${channel}Label`] || ''
    modal.querySelector('[data-route-send-name]').textContent = button.dataset.vehicleName || ''
    modal.querySelector('[data-route-send-submit]').value = modal.dataset[`${channel}Submit`] || ''
    window.bootstrap.Modal.getOrCreateInstance(modal).show()
  }

  toggleRouteTrace (event) {
    event.preventDefault()
    event.stopPropagation()
    const routeId = String(event.currentTarget.dataset.routeId || '')
    if (!routeId) return
    if (this._hiddenRouteIds.has(routeId)) this._hiddenRouteIds.delete(routeId)
    else this._hiddenRouteIds.add(routeId)
    this._persistRouteSelection()
    this._syncTraceButtons()
    this._applyRouteVisibility()
    this._addVehicleMarker()
  }

  toggleAllTraces (event) {
    event.preventDefault()
    const ids = this._traceRouteIds()
    const allHidden = ids.length > 0 && ids.every((id) => this._hiddenRouteIds.has(id))
    this._hiddenRouteIds = allHidden ? new Set() : new Set(ids)
    this._persistRouteSelection()
    this._syncTraceButtons()
    this._applyRouteVisibility()
    this._addVehicleMarker()
  }

  _revealRoute (routeId) {
    if (!this._hiddenRouteIds.delete(String(routeId))) return false
    this._syncTraceButtons()
    this._applyRouteVisibility()
    this._addVehicleMarker()
    return true
  }

  _traceRouteIds () {
    return [...this.element.querySelectorAll('[data-action*="toggleRouteTrace"]')].map((button) => String(button.dataset.routeId))
  }

  _syncTraceButtons () {
    const hidden = this._hiddenRouteIds
    this.element.querySelectorAll('[data-action*="toggleRouteTrace"]').forEach((button) => {
      this._paintEye(button, hidden.has(String(button.dataset.routeId)))
    })
    const all = this.element.querySelector('[data-action*="toggleAllTraces"]')
    if (!all) return
    const ids = this._traceRouteIds()
    this._paintEye(all, ids.length > 0 && ids.every((id) => hidden.has(id)))
  }

  _paintEye (button, hidden) {
    const icon = button.querySelector('i')
    if (icon) icon.className = hidden ? 'fa fa-eye-slash fa-fw' : 'fa fa-eye fa-fw'
    const label = hidden ? button.dataset.showLabel : button.dataset.hideLabel
    if (!label) return
    button.title = label
    button.setAttribute('aria-label', label)
  }

  _openRoute (routeId) {
    const details = this.element.querySelector(`details.operation-tour[data-route-id="${routeId}"]`)
    if (!details) return
    const host = this.element.querySelector('[data-controller~="exclusive-accordion"]')
    const accordion = host && this.application.getControllerForElementAndIdentifier(host, 'exclusive-accordion')
    if (accordion) {
      if (!accordion.isItemOpen(details)) accordion.openItem(details)
      else this._focusRoute(details)
      return
    }
    if (!details.open) details.open = true
    else this._focusRoute(details)
  }

  _locateRoute (routeId) {
    if (!this.map) return
    const position = this._vehiclePosition(routeId)
    if (!position) return
    const zoom = Math.max(this.map.getZoom(), 14)
    this._clearMapPadding()
    this.map.flyTo({ center: position, zoom, padding: this._mapPadding(), duration: 500 })
  }

  _syncVehicleButtons () {
    if (!this.geojson) return
    this.element.querySelectorAll('[data-action*="centerVehicle"]').forEach((button) => {
      button.disabled = !this._vehiclePosition(button.dataset.routeId)
    })
  }

  _fit () {
    const coords = []
    ;(this.geojson.features || []).forEach((feature) => {
      if (!feature.geometry || feature.geometry.type !== 'LineString') return
      feature.geometry.coordinates.forEach((pair) => coords.push(pair))
    })
    if (!coords.length || !this.map) return
    const maplibregl = window.maplibregl
    const bounds = coords.reduce((box, pair) => box.extend(pair), new maplibregl.LngLatBounds(coords[0], coords[0]))
    this._clearMapPadding()
    this.map.fitBounds(bounds, { padding: this._mapPadding(), maxZoom: 14 })
  }

  _fitRoute (routeId, waitForIdle) {
    if (!this.map || !this.geojson) return
    const coords = []
    const push = (pair) => {
      if (!pair) return
      const lng = Number(pair[0])
      const lat = Number(pair[1])
      if (Number.isFinite(lng) && Number.isFinite(lat)) coords.push([lng, lat])
    }
    ;(this.geojson.features || []).forEach((feature) => {
      const geometry = feature.geometry
      if (!geometry) return
      const props = feature.properties || {}
      if (props.geometry_kind === 'positions') return
      if (routeId && String(props.operation_route_id) !== String(routeId)) return
      if (geometry.type === 'LineString') geometry.coordinates.forEach(push)
      else if (geometry.type === 'Point') push(geometry.coordinates)
    })
    if (!coords.length) return
    const maplibregl = window.maplibregl
    const bounds = coords.reduce((box, pair) => box.extend(pair), new maplibregl.LngLatBounds(coords[0], coords[0]))
    const apply = () => {
      if (done || !this.map) return
      done = true
      this.map.stop()
      this._clearMapPadding()
      this.map.fitBounds(bounds, { padding: this._mapPadding(), maxZoom: 15, duration: 500 })
    }
    let done = false
    // setFilter is still settling when the trace was just shown again.
    if (waitForIdle) {
      this.map.once('idle', apply)
      window.setTimeout(apply, 300)
    } else {
      apply()
    }
  }

  _vehiclePosition (routeId) {
    const id = routeId || this.selectedRouteId
    if (!id || !this.geojson) return null
    const line = (this.geojson.features || []).find((feature) => {
      return feature.properties && feature.properties.geometry_kind === 'positions' && String(feature.properties.operation_route_id) === String(id)
    })
    const coords = line && line.geometry && line.geometry.coordinates
    if (!coords || !coords.length) return null
    return coords[coords.length - 1]
  }

  _syncStopClusters () {
    if (!this.map || !this.map.getSource('operation') || !window.maplibregl) return
    const features = this._stopFeatures()
    let clustered = features
    let open = []
    if (this._stopsDeclustered) {
      const bounds = this.map.getBounds()
      clustered = []
      features.forEach((feature) => {
        const coords = feature.geometry && feature.geometry.coordinates
        const inside = coords && coords[0] >= bounds.getWest() && coords[0] <= bounds.getEast() && coords[1] >= bounds.getSouth() && coords[1] <= bounds.getNorth()
        if (inside) open.push(feature)
        else clustered.push(feature)
      })
    }
    this._setStopSource(OPERATION_STOPS_SOURCE_ID, clustered, true)
    this._setStopSource(OPERATION_STOPS_OPEN_SOURCE_ID, open, false)
    this._syncDepotMarkers()
    if (this.map.getLayer(OPERATION_STOPS_LAYER_ID)) return
    this._onStopFeatureClick = (event) => {
      if (this._stopCluster) this._stopCluster.resetSelectedFeature()
      if (this._stopOpenCluster) this._stopOpenCluster.resetSelectedFeature()
      const feature = event.detail && event.detail.selectedFeature
      const stopId = feature && feature.properties && feature.properties.operation_stop_id
      if (stopId) this._showStopInPanels(stopId)
    }
    this._stopCluster = this._createStopCluster(OPERATION_STOPS_LAYER_ID, OPERATION_STOPS_SOURCE_ID)
    this._stopCluster.addEventListener('feature-click', this._onStopFeatureClick)
    this.map.addLayer(this._stopCluster)
    this._stopOpenCluster = this._createStopCluster(OPERATION_STOPS_OPEN_LAYER_ID, OPERATION_STOPS_OPEN_SOURCE_ID)
    this._stopOpenCluster.addEventListener('feature-click', this._onStopFeatureClick)
    this.map.addLayer(this._stopOpenCluster)
  }

  _setStopSource (id, features, cluster) {
    const data = { type: 'FeatureCollection', features }
    if (!this.map.getSource(id)) {
      const spec = { type: 'geojson', data }
      if (cluster) {
        spec.cluster = true
        spec.clusterMaxZoom = 22
        spec.clusterRadius = 50
      }
      this.map.addSource(id, spec)
    } else {
      this.map.getSource(id).setData(data)
    }
  }

  _createStopCluster (id, sourceId) {
    const maplibregl = window.maplibregl
    return new TeritorioCluster(id, sourceId, {
      clusterMaxZoom: 23,
      markerSize: 22,
      unfoldedClusterMaxLeaves: 7,
      clusterRender (element, props) {
        fillClusterMarker(element, props)
      },
      markerRender: (element, _size, feature) => this._fillStopMarker(element, feature),
      pinMarkerRender (coords, offset) {
        const el = document.createElement('div')
        el.className = 'destinations-marker-pin-placeholder'
        const marker = new maplibregl.Marker({ element: el }).setLngLat(coords)
        if (offset) marker.setOffset(offset)
        return marker
      }
    })
  }

  _stopFeatures () {
    const hidden = this._concealedRouteIds()
    const features = []
    ;(this.geojson?.features || []).forEach((feature) => {
      if (!feature.geometry || feature.geometry.type !== 'Point') return
      const props = feature.properties || {}
      if (props.kind === 'depot' || hidden.has(String(props.operation_route_id))) return
      const id = props.operation_stop_id != null
        ? `stop-${props.operation_stop_id}`
        : `depot-${props.operation_route_id}-${props.depot_role || 'point'}`
      features.push({ ...feature, properties: { ...props, id } })
    })
    return features
  }

  _showStopInPanels (stopId) {
    const row = this.element.querySelector(`.operation-stop-row[data-stop-id="${stopId}"]`)
    if (!row) return
    row.classList.remove('is-hidden')
    const tour = row.closest('details.operation-tour')
    if (tour && !tour.open) tour.open = true
    requestAnimationFrame(() => row.scrollIntoView({ block: 'center', behavior: 'smooth' }))
    row.click()
  }

  _fillStopMarker (element, feature) {
    const props = (feature && feature.properties) || {}
    const phase = props.phase
    const stopId = props.operation_stop_id != null ? String(props.operation_stop_id) : ''
    // The outer node is the MapLibre marker: its transform is the position.
    element.replaceChildren()
    element.className = 'operation-stop-marker'
    const disc = document.createElement('div')
    fillDestinationMarker(disc, { name: props.label, anchored: true })
    if (stopId) disc.dataset.stopId = stopId
    disc.style.setProperty('--dm-flat', PHASE_COLORS[phase] || props.color || '#3366cc')
    if (props.kind === 'depot') disc.classList.add('is-depot')
    if (phase) this._paintMarker(disc, phase)
    disc.classList.toggle('destinations-marker--active', this._activeStopId != null && stopId === String(this._activeStopId))
    element.appendChild(disc)
  }

  _paintActiveStop () {
    const id = this._activeStopId != null ? String(this._activeStopId) : ''
    const root = this.hasMapTarget ? this.mapTarget : this.element.querySelector('#map')
    if (!root) return
    root.querySelectorAll('.destinations-marker').forEach((disc) => {
      disc.classList.toggle('destinations-marker--active', id !== '' && disc.dataset.stopId === id)
    })
  }

  _concealedRouteIds () {
    const ids = new Set()
    ;(this._hiddenRouteIds || new Set()).forEach((id) => ids.add(String(id)))
    ;(this._excludedRouteIds || new Set()).forEach((id) => ids.add(String(id)))
    return ids
  }

  _routeCheckboxes () {
    return [...this.element.querySelectorAll('.operation-route-selector-option input[type="checkbox"]')]
  }

  _syncRouteSelectorLabel (count) {
    const label = this.element.querySelector('[data-route-selector-label]')
    const root = this.element.querySelector('[data-route-selector]')
    if (!label || !root) return
    if (count === 0) label.textContent = root.dataset.noneLabel || ''
    else if (count === 1) label.textContent = `1 ${root.dataset.oneLabel || ''}`
    else label.textContent = `${count} ${root.dataset.manyLabel || ''}`
  }

  _applyRouteVisibility () {
    const hidden = [...this._concealedRouteIds()]
    this._syncStopClusters()
    if (!this.map || !this.map.getLayer(OPERATION_LINES_LAYER_ID)) return
    const line = ['==', ['geometry-type'], 'LineString']
    if (!hidden.length) {
      this.map.setFilter(OPERATION_LINES_LAYER_ID, line)
    } else {
      this.map.setFilter(OPERATION_LINES_LAYER_ID, ['all', line, ['!', ['in', ['to-string', ['get', 'operation_route_id']], ['literal', hidden]]]])
    }
    this._paint()
  }

  _addVehicleMarker () {
    if (this._vehicleMarker) {
      this._vehicleMarker.remove()
      this._vehicleMarker = null
    }
    const maplibregl = window.maplibregl
    if (!maplibregl || !this.map || !this.selectedRouteId) return
    if (this._concealedRouteIds().has(String(this.selectedRouteId))) return
    const last = this._vehiclePosition()
    if (!last) return
    const el = document.createElement('div')
    el.className = 'operation-vehicle-pin'
    el.innerHTML = '<i class="fa fa-truck"></i>'
    this._vehicleMarker = new maplibregl.Marker({ element: el, anchor: 'center' }).setLngLat(last).addTo(this.map)
  }

  _syncDepotMarkers () {
    this._clearDepotMarkers()
    const maplibregl = window.maplibregl
    if (!maplibregl || !this.map) return
    const hidden = this._concealedRouteIds()
    this._depotMarkers = (this.geojson?.features || []).filter((feature) => {
      const props = feature.properties || {}
      return feature.geometry && feature.geometry.type === 'Point' && props.kind === 'depot' && !hidden.has(String(props.operation_route_id))
    }).map((feature) => {
      const props = feature.properties || {}
      const el = document.createElement('div')
      el.className = 'operation-stop-marker'
      const disc = document.createElement('div')
      fillDestinationMarker(disc, { name: props.label, anchored: true })
      disc.classList.add('is-depot')
      if (props.returns_complete) disc.classList.add('is-returned')
      el.appendChild(disc)
      return new maplibregl.Marker({ element: el, anchor: 'center' }).setLngLat(feature.geometry.coordinates).addTo(this.map)
    })
  }

  _clearDepotMarkers () {
    ;(this._depotMarkers || []).forEach((marker) => marker.remove())
    this._depotMarkers = []
  }

  _clearStopMarkers () {
    this._clearDepotMarkers()
    if (this._onStopFeatureClick) {
      if (this._stopCluster) this._stopCluster.removeEventListener('feature-click', this._onStopFeatureClick)
      if (this._stopOpenCluster) this._stopOpenCluster.removeEventListener('feature-click', this._onStopFeatureClick)
    }
    ;[OPERATION_STOPS_OPEN_LAYER_ID, OPERATION_STOPS_LAYER_ID].forEach((id) => {
      if (this.map && this.map.getLayer(id)) this.map.removeLayer(id)
    })
    ;[OPERATION_STOPS_OPEN_SOURCE_ID, OPERATION_STOPS_SOURCE_ID].forEach((id) => {
      if (this.map && this.map.getSource(id)) this.map.removeSource(id)
    })
    this._stopCluster = null
    this._stopOpenCluster = null
    this._onStopFeatureClick = null
  }

  _flyToStop ({ lng, lat, stopId }) {
    if (!this.map) return
    this._activeStopId = stopId
    this._paintActiveStop()
    this._syncStopClusters()
    const zoom = Math.max(this.map.getZoom(), 14)
    this._clearMapPadding()
    this.map.flyTo({ center: [lng, lat], zoom, padding: this._mapPadding(), duration: 500 })
  }

  // List and detail are flex siblings of the map (not overlays). map.resize() already
  // shrinks the canvas — counting their widths as padding made fitBounds a no-op after
  // flyTo (MapLibre keeps flyTo padding and sums it with the next fitBounds padding).
  _mapPadding () {
    return { top: 48, bottom: 48, left: 48, right: 48 }
  }

  _clearMapPadding () {
    if (!this.map) return
    this.map.setPadding({ top: 0, right: 0, bottom: 0, left: 0 })
  }

  _center () {
    const point = (this.geojson?.features || []).find((feature) => feature.geometry && feature.geometry.type === 'Point')
    if (point) return point.geometry.coordinates
    const params = this._mapParams || {}
    const lng = parseFloat(params.map_lng)
    const lat = parseFloat(params.map_lat)
    if (Number.isFinite(lng) && Number.isFinite(lat)) return [lng, lat]
    return [2.3, 48.8]
  }

  _paint () {
    if (!this.map || !this.map.getLayer(OPERATION_LINES_LAYER_ID)) return
    const selected = this.selectedRouteId ? String(this.selectedRouteId) : ''
    const positions = ['==', ['get', 'geometry_kind'], 'positions']
    const width = selected
      ? ['case',
          ['==', ['to-string', ['get', 'operation_route_id']], selected], 6,
          positions, 4,
          3]
      : ['case', positions, 4, 3]
    this.map.setPaintProperty(OPERATION_LINES_LAYER_ID, 'line-width', width)
    this.map.setPaintProperty(OPERATION_LINES_LAYER_ID, 'line-opacity', ['coalesce', ['get', 'opacity'], OPACITY_MAX])
  }
}

// Turbo Streams arrive on <turbo-cable-stream-source>. The v2 bundle loads Turbo
// without the turbo-rails Action Cable element, so this page registers it.
const cableSockets = new Map()

function cableSocket () {
  const url = `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}/cable`
  const existing = cableSockets.get(url)
  if (existing && existing.readyState <= WebSocket.OPEN) return existing
  const socket = new WebSocket(url, 'actioncable-v1-json')
  socket.pending = []
  socket.sources = new Map()
  socket.onmessage = (event) => {
    let data
    try { data = JSON.parse(event.data) } catch (error) { return }
    if (data.type === 'welcome') {
      socket.pending.splice(0).forEach((message) => socket.send(message))
      return
    }
    if (data.type === 'ping' || data.type === 'confirm_subscription' || data.type === 'reject_subscription') return
    const source = data.identifier && socket.sources.get(data.identifier)
    if (source && data.message) source.dispatchEvent(new MessageEvent('message', { data: data.message }))
  }
  cableSockets.set(url, socket)
  return socket
}

class TurboCableStreamSourceElement extends HTMLElement {
  connectedCallback () {
    connectStreamSource(this)
    const identifier = JSON.stringify({
      channel: this.getAttribute('channel') || 'Turbo::StreamsChannel',
      signed_stream_name: this.getAttribute('signed-stream-name')
    })
    this.cableIdentifier = identifier
    const socket = cableSocket()
    socket.sources.set(identifier, this)
    const command = JSON.stringify({ command: 'subscribe', identifier })
    if (socket.readyState === WebSocket.OPEN) socket.send(command)
    else socket.pending.push(command)
  }

  disconnectedCallback () {
    disconnectStreamSource(this)
    const socket = cableSockets.get(`${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}/cable`)
    if (!socket || !this.cableIdentifier) return
    socket.sources.delete(this.cableIdentifier)
    const command = JSON.stringify({ command: 'unsubscribe', identifier: this.cableIdentifier })
    if (socket.readyState === WebSocket.OPEN) socket.send(command)
  }
}

if (!customElements.get('turbo-cable-stream-source')) {
  customElements.define('turbo-cable-stream-source', TurboCableStreamSourceElement)
}
