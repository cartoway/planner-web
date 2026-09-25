// Copyright © Cartoway
// destination_markers.js is ESM for the importmap. Node 18 treats .js as CommonJS,
// so the test loads the same source as an .mjs module.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/maplibre/destination_markers.js', import.meta.url)
const tmpPath = path.join(os.tmpdir(), 'planner-destination-markers.mjs')
fs.writeFileSync(tmpPath, fs.readFileSync(srcPath))
const { clusterMarkerSize, fillClusterMarker, fillDestinationMarker } = await import(pathToFileURL(tmpPath).href)

function element () {
  return {
    className: '',
    attrs: {},
    children: [],
    textContent: '',
    style: {},
    setAttribute (key, value) { this.attrs[key] = value },
    removeAttribute (key) { delete this.attrs[key] },
    appendChild (child) { this.children.push(child) },
    replaceChildren () { this.children = [] }
  }
}

globalThis.document = {
  createElement () { return element() }
}

describe('destination HTML markers', () => {
  it('builds a pin with the destination name', () => {
    const el = element()
    fillDestinationMarker(el, { name: 'Depot', anchored: true })

    assert.equal(el.className, 'destinations-marker destinations-marker--anchored')
    assert.equal(el.attrs['aria-label'], 'Depot')
    assert.equal(el.attrs.role, 'button')
    assert.equal(el.children.length, 2)
    assert.equal(el.children[0].className, 'destinations-marker__head')
    assert.equal(el.children[1].className, 'destinations-marker__pin')
  })

  it('sizes the cluster bubble from the point count', () => {
    assert.equal(clusterMarkerSize(3), 36)
    assert.equal(clusterMarkerSize(25), 44)
    assert.equal(clusterMarkerSize(100), 52)

    const el = element()
    fillClusterMarker(el, { point_count: 40, point_count_abbreviated: '40' })
    assert.equal(el.className, 'destinations-cluster')
    assert.equal(el.textContent, '40')
    assert.equal(el.style.width, '44px')
    assert.equal(el.style.height, '44px')
  })
})
