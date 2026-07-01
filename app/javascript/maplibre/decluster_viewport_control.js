// Copyright © Cartoway
// MapLibre IControl: toggle decluster / recluster for the current viewport (planning v1 icons).

const DEFAULT_ROOT_CLASS = 'maplibregl-ctrl maplibregl-ctrl-group maplibre-decluster-viewport'

/**
 * @param {{
 *   getDeclustered: () => boolean,
 *   onToggle: (declustered: boolean) => void,
 *   titleDecluster: string,
 *   titleRecluster: string,
 *   rootClass?: string
 * }} options
 */
export function DeclusterViewportIControl (options) {
  this._getDeclustered = options.getDeclustered
  this._onToggle = options.onToggle
  this._titleDecluster = options.titleDecluster || 'De-cluster visible points'
  this._titleRecluster = options.titleRecluster || 'Cluster visible points'
  this._rootClass = options.rootClass || DEFAULT_ROOT_CLASS
}

DeclusterViewportIControl.prototype._syncUi = function () {
  if (!this._btn || !this._iconEl) return
  const declustered = typeof this._getDeclustered === 'function' && this._getDeclustered()
  // Same icons as planning v1 (L.disableClustersControl in scaffolds.js).
  this._iconEl.className = declustered
    ? 'fa fa-arrows-to-circle fa-lg'
    : 'fa fa-shapes fa-lg'
  const title = declustered ? this._titleRecluster : this._titleDecluster
  this._btn.setAttribute('title', title)
  this._btn.setAttribute('aria-label', title)
  this._btn.setAttribute('aria-pressed', declustered ? 'true' : 'false')
}

DeclusterViewportIControl.prototype.onAdd = function () {
  const wrap = document.createElement('div')
  wrap.className = this._rootClass

  const btn = document.createElement('button')
  btn.type = 'button'
  btn.className = 'maplibregl-ctrl-icon'
  btn.addEventListener('click', () => {
    if (typeof this._getDeclustered !== 'function' || typeof this._onToggle !== 'function') return
    const next = !this._getDeclustered()
    this._onToggle(next)
    this._syncUi()
  })

  const icon = document.createElement('i')
  icon.setAttribute('aria-hidden', 'true')
  icon.style.marginLeft = '2px'
  btn.appendChild(icon)

  wrap.appendChild(btn)
  this._container = wrap
  this._btn = btn
  this._iconEl = icon
  this._syncUi()
  return wrap
}

DeclusterViewportIControl.prototype.onRemove = function () {
  if (this._container && this._container.parentNode) {
    this._container.parentNode.removeChild(this._container)
  }
  this._btn = null
  this._iconEl = null
}

DeclusterViewportIControl.prototype.getDefaultPosition = function () {
  return 'top-right'
}

/** Call when decluster state changes outside the control (e.g. map reload). */
DeclusterViewportIControl.prototype.syncUi = function () {
  this._syncUi()
}
