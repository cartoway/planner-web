// Copyright © Cartoway
// MapLibre IControl: show viewport points as individuals (no clustering, no zoom change).

const DEFAULT_ROOT_CLASS = 'maplibregl-ctrl maplibregl-ctrl-group maplibre-decluster-viewport'

/**
 * @param {() => void} onDecluster
 * @param {string} title
 * @param {{ rootClass?: string }} [options]
 */
export function DeclusterViewportIControl (onDecluster, title, options = {}) {
  this._onDecluster = onDecluster
  this._title = title || 'De-cluster visible points'
  this._rootClass = options.rootClass || DEFAULT_ROOT_CLASS
}

DeclusterViewportIControl.prototype.onAdd = function () {
  const wrap = document.createElement('div')
  wrap.className = this._rootClass

  const btn = document.createElement('button')
  btn.type = 'button'
  btn.className = 'maplibregl-ctrl-icon'
  btn.setAttribute('title', this._title)
  btn.setAttribute('aria-label', this._title)
  btn.addEventListener('click', () => {
    if (typeof this._onDecluster === 'function') this._onDecluster()
  })

  const icon = document.createElement('i')
  icon.className = 'fa fa-object-ungroup'
  icon.setAttribute('aria-hidden', 'true')
  btn.appendChild(icon)

  wrap.appendChild(btn)
  this._container = wrap
  return wrap
}

DeclusterViewportIControl.prototype.onRemove = function () {
  if (this._container && this._container.parentNode) {
    this._container.parentNode.removeChild(this._container)
  }
}

DeclusterViewportIControl.prototype.getDefaultPosition = function () {
  return 'top-right'
}
