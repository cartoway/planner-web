// Copyright © Cartoway
// MapLibre IControl: checkboxes to toggle raster overlay layer visibility.

const DEFAULT_ROOT_CLASS = 'maplibregl-ctrl maplibregl-ctrl-group maplibre-overlay-toggles'

/**
 * @param {{ layerId: string, name: string, initialVisible?: boolean }[]} overlaySpecs
 * @param {string} summaryTitle - native tooltip + aria-label on the summary control (no visible text)
 * @param {{ rootClass?: string, summaryClass?: string, bodyClass?: string, inputIdPrefix?: string }} [options]
 */
export function OverlayLayersToggleIControl (overlaySpecs, summaryTitle, options = {}) {
  this._specs = overlaySpecs
  this._summaryTitle = summaryTitle || 'Overlays'
  this._rootClass = options.rootClass || DEFAULT_ROOT_CLASS
  this._summaryClass = options.summaryClass || 'maplibre-overlay-toggles-summary'
  this._bodyClass = options.bodyClass || 'maplibre-overlay-toggles-body'
  this._inputIdPrefix = options.inputIdPrefix || 'maplibre-overlay-'
}

OverlayLayersToggleIControl.prototype.onAdd = function (map) {
  const wrap = document.createElement('div')
  wrap.className = this._rootClass
  const details = document.createElement('details')
  const summary = document.createElement('summary')
  summary.className = this._summaryClass
  summary.setAttribute('title', this._summaryTitle)
  summary.setAttribute('aria-label', this._summaryTitle)
  const icon = document.createElement('i')
  icon.className = 'fa fa-layer-group fa-fw'
  icon.setAttribute('aria-hidden', 'true')
  summary.appendChild(icon)
  const body = document.createElement('div')
  body.className = this._bodyClass
  const prefix = this._inputIdPrefix
  this._specs.forEach((spec, idx) => {
    const row = document.createElement('div')
    row.className = 'form-check mb-1'
    const inputId = prefix + idx
    const cb = document.createElement('input')
    cb.type = 'checkbox'
    cb.className = 'form-check-input'
    cb.id = inputId
    cb.checked = !!spec.initialVisible
    cb.addEventListener('change', () => {
      map.setLayoutProperty(spec.layerId, 'visibility', cb.checked ? 'visible' : 'none')
    })
    const lbl = document.createElement('label')
    lbl.className = 'form-check-label'
    lbl.setAttribute('for', inputId)
    lbl.textContent = spec.name
    row.appendChild(cb)
    row.appendChild(lbl)
    body.appendChild(row)
  })
  details.appendChild(summary)
  details.appendChild(body)
  wrap.appendChild(details)
  this._container = wrap
  return wrap
}

OverlayLayersToggleIControl.prototype.onRemove = function () {
  if (this._container && this._container.parentNode) {
    this._container.parentNode.removeChild(this._container)
  }
}

OverlayLayersToggleIControl.prototype.getDefaultPosition = function () {
  return 'top-right'
}
