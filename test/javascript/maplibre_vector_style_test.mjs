// Copyright © Cartoway
// Keep in sync with app/javascript/maplibre/raster_layers.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

function resolveMapStyleMode (mapLayers) {
  const bases = Object.values(mapLayers || {}).filter((l) => !l.overlay)
  const defaultBase = bases.find((b) => b.default) || bases[0]
  const vectorUrl = defaultBase && (defaultBase.vector_url || defaultBase.vectorUrl)
  return vectorUrl ? { mode: 'vector', style: vectorUrl } : { mode: 'raster' }
}

describe('resolveMapStyle prefers vector_url as-is', () => {
  it('uses the default base vector_url without rewriting the host', () => {
    const styleUrl = 'https://maps.example.com/styles/custom/style.json'
    const resolved = resolveMapStyleMode({
      Custom: {
        name: 'Custom',
        url: 'https://tiles.example.com/{z}/{x}/{y}.png',
        vector_url: styleUrl,
        default: true,
        overlay: false
      }
    })
    assert.equal(resolved.mode, 'vector')
    assert.equal(resolved.style, styleUrl)
  })

  it('falls back to raster when vector_url is absent', () => {
    const resolved = resolveMapStyleMode({
      Osm: {
        name: 'Osm',
        url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        default: true,
        overlay: false
      }
    })
    assert.equal(resolved.mode, 'raster')
  })

  it('keeps overlay data layers selectable alongside a vector base', () => {
    const layers = {
      VectorBase: {
        name: 'VectorBase',
        url: 'https://tiles.example.com/{z}/{x}/{y}.png',
        vector_url: 'https://maps.example.com/style.json',
        default: true,
        overlay: false
      },
      Restrictions: {
        name: 'Restrictions',
        url: 'https://maps.example.com/overlays/truck/{z}/{x}/{y}.png',
        default: false,
        overlay: true
      }
    }
    const overlays = Object.values(layers).filter((l) => l.overlay)
    assert.equal(overlays.length, 1)
    assert.equal(overlays[0].name, 'Restrictions')
  })
})
