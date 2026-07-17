// Copyright © Cartoway
// MapLibre IControl: geocoder against /api/0.1/geocoder/search (same-origin JSON).

const DEFAULT_CLASSES = {
  root: 'maplibregl-ctrl maplibregl-ctrl-group maplibre-geocoder',
  form: 'maplibre-geocoder-form input-group input-group-sm d-none',
  toggle: 'maplibre-geocoder-toggle',
  results: 'maplibre-geocoder-results list-unstyled d-none',
  resultItem: 'maplibre-geocoder-result px-2 py-1'
}

const MIN_CHARS = 3
const DEBOUNCE_MS = 300

/**
 * @param {string} placeholder
 * @param {string} emptyMsg
 * @param {{ searchUrl?: string, tooltip?: string, submitLabel?: string, minChars?: number, debounceMs?: number, classes?: Partial<typeof DEFAULT_CLASSES> }} [options]
 */
export function GeocoderIControl (placeholder, emptyMsg, options = {}) {
  this._placeholder = placeholder
  this._emptyMsg = emptyMsg
  this._tooltip = options.tooltip || placeholder
  this._submitLabel = options.submitLabel || placeholder
  this._searchUrl = options.searchUrl || '/api/0.1/geocoder/search'
  this._minChars = options.minChars != null ? options.minChars : MIN_CHARS
  this._debounceMs = options.debounceMs != null ? options.debounceMs : DEBOUNCE_MS
  this._classes = { ...DEFAULT_CLASSES, ...(options.classes || {}) }
  this._debounceTimer = null
  this._abort = null
  this._activeIndex = -1
}

GeocoderIControl.prototype.onAdd = function (map) {
  const self = this
  this._map = map
  const C = this._classes
  const container = document.createElement('div')
  container.className = C.root

  const toggle = document.createElement('button')
  toggle.type = 'button'
  toggle.className = C.toggle
  toggle.title = self._tooltip
  toggle.setAttribute('aria-label', self._tooltip)
  toggle.setAttribute('aria-expanded', 'false')
  toggle.innerHTML = '<span class="fa fa-search" aria-hidden="true"></span>'

  const form = document.createElement('div')
  form.className = C.form
  const input = document.createElement('input')
  input.type = 'search'
  input.className = 'form-control'
  input.placeholder = self._placeholder
  input.autocomplete = 'off'
  input.setAttribute('aria-label', self._placeholder)
  input.setAttribute('aria-autocomplete', 'list')
  input.setAttribute('role', 'combobox')
  input.setAttribute('aria-expanded', 'false')
  const btn = document.createElement('button')
  btn.type = 'button'
  btn.className = 'btn btn-outline-secondary'
  btn.title = self._submitLabel
  btn.setAttribute('aria-label', self._submitLabel)
  btn.innerHTML = '<span class="fa fa-search" aria-hidden="true"></span>'
  const list = document.createElement('ul')
  list.className = C.results
  list.setAttribute('role', 'listbox')

  this._input = input
  this._list = list

  function cancelPending () {
    if (self._debounceTimer) {
      clearTimeout(self._debounceTimer)
      self._debounceTimer = null
    }
    if (self._abort) {
      self._abort.abort()
      self._abort = null
    }
  }

  function collapseResults () {
    list.classList.add('d-none')
    list.innerHTML = ''
    self._activeIndex = -1
    input.setAttribute('aria-expanded', 'false')
  }

  function collapse () {
    cancelPending()
    collapseResults()
    form.classList.add('d-none')
    toggle.classList.remove('d-none')
    toggle.setAttribute('aria-expanded', 'false')
    container.classList.remove('maplibre-geocoder--expanded')
    input.blur()
  }

  function expand () {
    toggle.classList.add('d-none')
    form.classList.remove('d-none')
    toggle.setAttribute('aria-expanded', 'true')
    container.classList.add('maplibre-geocoder--expanded')
    input.focus()
  }

  function flyToHit (hit) {
    const lat = parseFloat(hit.lat)
    const lon = parseFloat(hit.lon)
    if (!isFinite(lat) || !isFinite(lon)) return
    const bb = hit.boundingbox
    if (Array.isArray(bb) && bb.length >= 4) {
      const lat0 = parseFloat(bb[0]); const lat1 = parseFloat(bb[1])
      const lng0 = parseFloat(bb[2]); const lng1 = parseFloat(bb[3])
      if (isFinite(lat0) && isFinite(lat1) && isFinite(lng0) && isFinite(lng1)) {
        map.fitBounds([[lng0, lat0], [lng1, lat1]], { padding: 48, maxZoom: 15, duration: 600 })
        return
      }
    }
    map.flyTo({ center: [lon, lat], zoom: 15 })
  }

  function selectHit (hit) {
    if (hit && hit.display_name) input.value = hit.display_name
    if (hit) flyToHit(hit)
    collapse()
  }

  function highlightActive () {
    const items = list.querySelectorAll('[data-geocoder-index]')
    items.forEach((el, i) => {
      el.classList.toggle('active', i === self._activeIndex)
      if (i === self._activeIndex) el.setAttribute('aria-selected', 'true')
      else el.removeAttribute('aria-selected')
    })
    if (self._activeIndex >= 0 && items[self._activeIndex]) {
      items[self._activeIndex].scrollIntoView({ block: 'nearest' })
    }
  }

  function renderResults (data) {
    list.innerHTML = ''
    self._activeIndex = -1
    if (!Array.isArray(data) || data.length === 0) {
      const li = document.createElement('li')
      li.className = 'text-muted small px-2 py-1'
      li.textContent = self._emptyMsg
      list.appendChild(li)
      list.classList.remove('d-none')
      input.setAttribute('aria-expanded', 'true')
      return
    }
    data.forEach((hit, idx) => {
      const li = document.createElement('li')
      li.className = C.resultItem
      li.setAttribute('role', 'option')
      li.setAttribute('data-geocoder-index', String(idx))
      li.textContent = hit.display_name || ''
      li.addEventListener('mousedown', (e) => { e.preventDefault() })
      li.addEventListener('click', () => selectHit(hit))
      li.addEventListener('mouseenter', () => {
        self._activeIndex = idx
        highlightActive()
      })
      list.appendChild(li)
    })
    list.classList.remove('d-none')
    input.setAttribute('aria-expanded', 'true')
  }

  function runSearch () {
    const q = (input.value || '').trim()
    if (!q || q.length < self._minChars) {
      collapseResults()
      return
    }
    if (self._abort) self._abort.abort()
    const controller = new AbortController()
    self._abort = controller
    const center = map.getCenter()
    const params = new URLSearchParams({ q, lat: String(center.lat), lng: String(center.lng), limit: '8' })
    fetch(self._searchUrl + '?' + params.toString(), {
      headers: { Accept: 'application/json' },
      credentials: 'same-origin',
      signal: controller.signal
    })
      .then((r) => r.json())
      .then((data) => {
        if (controller.signal.aborted) return
        renderResults(data)
      })
      .catch((err) => {
        if (err && err.name === 'AbortError') return
        list.innerHTML = ''
        const li = document.createElement('li')
        li.className = 'text-danger small px-2 py-1'
        li.textContent = self._emptyMsg
        list.appendChild(li)
        list.classList.remove('d-none')
        input.setAttribute('aria-expanded', 'true')
      })
  }

  function scheduleSearch () {
    if (self._debounceTimer) clearTimeout(self._debounceTimer)
    self._debounceTimer = setTimeout(() => {
      self._debounceTimer = null
      runSearch()
    }, self._debounceMs)
  }

  function moveActive (delta) {
    const items = list.querySelectorAll('[data-geocoder-index]')
    if (!items.length || list.classList.contains('d-none')) return
    const next = self._activeIndex + delta
    if (next < 0) self._activeIndex = items.length - 1
    else if (next >= items.length) self._activeIndex = 0
    else self._activeIndex = next
    highlightActive()
  }

  toggle.addEventListener('click', (e) => {
    e.preventDefault()
    e.stopPropagation()
    expand()
  })
  btn.addEventListener('click', () => {
    cancelPending()
    runSearch()
  })
  input.addEventListener('input', scheduleSearch)
  input.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      moveActive(1)
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      moveActive(-1)
    } else if (e.key === 'Enter') {
      e.preventDefault()
      const items = list.querySelectorAll('[data-geocoder-index]')
      if (self._activeIndex >= 0 && items[self._activeIndex]) {
        items[self._activeIndex].click()
        return
      }
      cancelPending()
      runSearch()
    } else if (e.key === 'Escape') {
      e.preventDefault()
      if (!list.classList.contains('d-none')) collapseResults()
      else collapse()
    }
  })
  this._outside = (e) => {
    if (!container.contains(e.target)) collapse()
  }
  document.addEventListener('click', this._outside)

  form.appendChild(input)
  form.appendChild(btn)
  container.appendChild(toggle)
  container.appendChild(form)
  container.appendChild(list)
  this._container = container
  this._cancelPending = cancelPending
  this._collapse = collapse
  return container
}

GeocoderIControl.prototype.onRemove = function () {
  if (this._cancelPending) this._cancelPending()
  if (this._outside) document.removeEventListener('click', this._outside)
  if (this._container && this._container.parentNode) {
    this._container.parentNode.removeChild(this._container)
  }
}

GeocoderIControl.prototype.getDefaultPosition = function () {
  return 'top-right'
}
