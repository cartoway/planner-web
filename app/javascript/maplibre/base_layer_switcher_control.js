// Copyright © Cartoway
// MapLibre IControl: single-select among mutually exclusive raster base layers (visibility).

const DEFAULT_ROOT_CLASS = 'maplibregl-ctrl maplibregl-ctrl-group maplibre-layer-switch'

/**
 * @param {string[]} baseLayerIds - Map layer ids (e.g. base-0-layer)
 * @param {{ name: string, default?: boolean }[]} bases - Metadata aligned with baseLayerIds order
 * @param {{ rootClass?: string }} [options]
 */
export function BaseLayerSwitcherIControl (baseLayerIds, bases, options = {}) {
  this._baseLayerIds = baseLayerIds
  this._bases = bases
  this._rootClass = options.rootClass || DEFAULT_ROOT_CLASS
}

BaseLayerSwitcherIControl.prototype.onAdd = function (map) {
  const bases = this._bases
  const wrap = document.createElement('div')
  wrap.className = this._rootClass
  const sel = document.createElement('select')
  sel.className = 'form-select form-select-sm'
  let selectedIdx = 0
  bases.forEach((b, i) => {
    if (b.default) selectedIdx = i
  })
  if (!bases.some((b) => b.default)) selectedIdx = 0
  const self = this
  bases.forEach((b, i) => {
    const opt = document.createElement('option')
    opt.value = 'base-' + i + '-layer'
    opt.textContent = b.name
    if (i === selectedIdx) opt.selected = true
    sel.appendChild(opt)
  })
  sel.addEventListener('change', () => {
    self._baseLayerIds.forEach((lid) => {
      map.setLayoutProperty(lid, 'visibility', lid === sel.value ? 'visible' : 'none')
    })
  })
  wrap.appendChild(sel)
  this._container = wrap
  return wrap
}

BaseLayerSwitcherIControl.prototype.onRemove = function () {
  if (this._container && this._container.parentNode) {
    this._container.parentNode.removeChild(this._container)
  }
}

BaseLayerSwitcherIControl.prototype.getDefaultPosition = function () {
  return 'top-right'
}
