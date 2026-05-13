// Copyright © Cartoway
// MapLibre IControl: geocoder against /api/0.1/geocoder/search (same-origin JSON).
// Reusable on any page that loads MapLibre GL and Bootstrap-ish markup.

const DEFAULT_CLASSES = {
  root: 'maplibregl-ctrl maplibregl-ctrl-group cartoway-maplibre-geocoder',
  form: 'cartoway-maplibre-geocoder-form input-group input-group-sm',
  results: 'cartoway-maplibre-geocoder-results list-unstyled d-none',
  resultItem: 'cartoway-maplibre-geocoder-result px-2 py-1'
}

/**
 * @param {string} placeholder
 * @param {string} emptyMsg
 * @param {{ searchUrl?: string, classes?: Partial<typeof DEFAULT_CLASSES> }} [options]
 */
export function GeocoderIControl (placeholder, emptyMsg, options = {}) {
  this._placeholder = placeholder
  this._emptyMsg = emptyMsg
  this._searchUrl = options.searchUrl || '/api/0.1/geocoder/search'
  this._classes = { ...DEFAULT_CLASSES, ...(options.classes || {}) }
}

GeocoderIControl.prototype.onAdd = function (map) {
  const self = this
  this._map = map
  const C = this._classes
  const container = document.createElement('div')
  container.className = C.root
  const form = document.createElement('div')
  form.className = C.form
  const input = document.createElement('input')
  input.type = 'search'
  input.className = 'form-control'
  input.placeholder = self._placeholder
  input.autocomplete = 'off'
  const btn = document.createElement('button')
  btn.type = 'button'
  btn.className = 'btn btn-outline-secondary'
  btn.innerHTML = '<span class="fa fa-search" aria-hidden="true"></span>'
  const list = document.createElement('ul')
  list.className = C.results

  function collapse () {
    list.classList.add('d-none')
    list.innerHTML = ''
  }

  function runSearch () {
    const q = (input.value || '').trim()
    if (!q) return
    list.innerHTML = ''
    list.classList.remove('d-none')
    const center = map.getCenter()
    const params = new URLSearchParams({ q, lat: String(center.lat), lng: String(center.lng), limit: '8' })
    fetch(self._searchUrl + '?' + params.toString(), { headers: { Accept: 'application/json' }, credentials: 'same-origin' })
      .then((r) => r.json())
      .then((data) => {
        list.innerHTML = ''
        if (!Array.isArray(data) || data.length === 0) {
          const li = document.createElement('li')
          li.className = 'text-muted small px-2 py-1'
          li.textContent = self._emptyMsg
          list.appendChild(li)
          return
        }
        data.forEach((hit) => {
          const li = document.createElement('li')
          li.className = C.resultItem
          li.textContent = hit.display_name || ''
          li.addEventListener('mousedown', (e) => { e.preventDefault() })
          li.addEventListener('click', () => {
            const lat = parseFloat(hit.lat)
            const lon = parseFloat(hit.lon)
            if (isFinite(lat) && isFinite(lon)) {
              const bb = hit.boundingbox
              if (Array.isArray(bb) && bb.length >= 4) {
                const lat0 = parseFloat(bb[0]); const lat1 = parseFloat(bb[1])
                const lng0 = parseFloat(bb[2]); const lng1 = parseFloat(bb[3])
                if (isFinite(lat0) && isFinite(lat1) && isFinite(lng0) && isFinite(lng1)) {
                  map.fitBounds([[lng0, lat0], [lng1, lat1]], { padding: 48, maxZoom: 15, duration: 600 })
                } else {
                  map.flyTo({ center: [lon, lat], zoom: 15 })
                }
              } else {
                map.flyTo({ center: [lon, lat], zoom: 15 })
              }
            }
            collapse()
            input.blur()
          })
          list.appendChild(li)
        })
      })
      .catch(() => {
        list.innerHTML = ''
        const li = document.createElement('li')
        li.className = 'text-danger small px-2 py-1'
        li.textContent = self._emptyMsg
        list.appendChild(li)
      })
  }

  btn.addEventListener('click', runSearch)
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault()
      runSearch()
    }
  })
  this._outside = (e) => {
    if (!container.contains(e.target)) collapse()
  }
  document.addEventListener('click', this._outside)

  form.appendChild(input)
  form.appendChild(btn)
  container.appendChild(form)
  container.appendChild(list)
  this._container = container
  return container
}

GeocoderIControl.prototype.onRemove = function () {
  if (this._outside) document.removeEventListener('click', this._outside)
  if (this._container && this._container.parentNode) {
    this._container.parentNode.removeChild(this._container)
  }
}

GeocoderIControl.prototype.getDefaultPosition = function () {
  return 'top-right'
}
