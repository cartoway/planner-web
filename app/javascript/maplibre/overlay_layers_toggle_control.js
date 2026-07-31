// Copyright © Cartoway
// MapLibre IControl: base maps (radio) + overlay layers (checkbox) in one panel.

const DEFAULT_ROOT_CLASS = 'maplibregl-ctrl maplibregl-ctrl-group maplibre-overlay-toggles'

/**
 * @param {{ layerId: string, name: string, initialVisible?: boolean }[]} overlaySpecs
 * @param {string} summaryTitle - native tooltip + aria-label on the summary control (no visible text)
 * @param {{
 *   rootClass?: string,
 *   summaryClass?: string,
 *   bodyClass?: string,
 *   inputIdPrefix?: string,
 *   bases?: { layerId: string, name: string, selected?: boolean }[],
 *   baseSectionTitle?: string,
 *   overlaySectionTitle?: string
 * }} [options]
 */
export function OverlayLayersToggleIControl (overlaySpecs, summaryTitle, options = {}) {
  this._specs = overlaySpecs || []
  this._bases = options.bases || []
  this._summaryTitle = summaryTitle || 'Layers'
  this._baseSectionTitle = options.baseSectionTitle || ''
  this._overlaySectionTitle = options.overlaySectionTitle || ''
  this._rootClass = options.rootClass || DEFAULT_ROOT_CLASS
  this._summaryClass = options.summaryClass || 'maplibre-overlay-toggles-summary'
  this._bodyClass = options.bodyClass || 'maplibre-overlay-toggles-body'
  this._inputIdPrefix = options.inputIdPrefix || 'maplibre-layer-'
  this._onBaseChange = options.onBaseChange || null
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
  const bases = this._bases
  const overlays = this._specs
  const showBaseHeading = bases.length > 0 && overlays.length > 0 && this._baseSectionTitle
  const showOverlayHeading = bases.length > 0 && overlays.length > 0 && this._overlaySectionTitle

  if (showBaseHeading) {
    const heading = document.createElement('div')
    heading.className = 'maplibre-overlay-toggles-heading'
    heading.textContent = this._baseSectionTitle
    body.appendChild(heading)
  }

  const radioName = prefix + 'base'
  const onBaseChange = this._onBaseChange
  bases.forEach((spec, idx) => {
    const row = document.createElement('div')
    row.className = 'form-check mb-1'
    const inputId = prefix + 'base-' + idx
    const radio = document.createElement('input')
    radio.type = 'radio'
    radio.className = 'form-check-input'
    radio.name = radioName
    radio.id = inputId
    radio.checked = !!spec.selected
    radio.addEventListener('change', () => {
      if (!radio.checked) return
      if (typeof onBaseChange === 'function') {
        onBaseChange(spec, bases)
        return
      }
      bases.forEach((b) => {
        if (!b.layerId) return
        map.setLayoutProperty(b.layerId, 'visibility', b.layerId === spec.layerId ? 'visible' : 'none')
      })
    })
    const lbl = document.createElement('label')
    lbl.className = 'form-check-label'
    lbl.setAttribute('for', inputId)
    lbl.textContent = spec.name
    row.appendChild(radio)
    row.appendChild(lbl)
    body.appendChild(row)
  })

  if (showOverlayHeading) {
    const heading = document.createElement('div')
    heading.className = 'maplibre-overlay-toggles-heading'
    heading.textContent = this._overlaySectionTitle
    body.appendChild(heading)
  }

  overlays.forEach((spec, idx) => {
    const row = document.createElement('div')
    row.className = 'form-check mb-1'
    const inputId = prefix + 'overlay-' + idx
    const cb = document.createElement('input')
    cb.type = 'checkbox'
    cb.className = 'form-check-input'
    cb.id = inputId
    cb.checked = !!spec.initialVisible
    cb.addEventListener('change', () => {
      const ids = (spec.layerIds && spec.layerIds.length) ? spec.layerIds : (spec.layerId ? [spec.layerId] : [])
      ids.forEach((layerId) => {
        if (!map.getLayer(layerId)) return
        map.setLayoutProperty(layerId, 'visibility', cb.checked ? 'visible' : 'none')
      })
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
