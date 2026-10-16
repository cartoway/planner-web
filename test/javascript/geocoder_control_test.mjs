// Copyright © Cartoway
// geocoder_control.js is ESM for the importmap. Node 18 treats .js as CommonJS,
// so the test loads the same source as an .mjs module.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/maplibre/geocoder_control.js', import.meta.url)
const tmpPath = path.join(os.tmpdir(), 'planner-geocoder-control.mjs')
fs.writeFileSync(tmpPath, fs.readFileSync(srcPath))
const { createFocusGeocoderElement, shouldClearGeocoderFocus } = await import(pathToFileURL(tmpPath).href)

function element (className = '', parent = null) {
  const el = {
    className,
    parentElement: parent,
    nodeType: 1,
    attrs: {},
    setAttribute (key, value) { this.attrs[key] = value },
    closest (selector) {
      const name = selector.startsWith('.') ? selector.slice(1) : selector
      let cur = this
      while (cur) {
        const classes = String(cur.className || '').split(/\s+/)
        if (classes.includes(name) || cur.id === name.replace(/^#/, '')) return cur
        cur = cur.parentElement
      }
      return null
    }
  }
  return el
}

describe('createFocusGeocoderElement', () => {
  it('builds a focus-geocoder pin element', () => {
    globalThis.document = {
      createElement () {
        return element()
      }
    }
    const el = createFocusGeocoderElement()
    assert.equal(el.className, 'focus-geocoder')
    assert.equal(el.attrs['aria-hidden'], 'true')
  })
})

describe('shouldClearGeocoderFocus', () => {
  it('clears on dismiss selectors and skips ignore selectors', () => {
    const list = element('operation-list')
    const row = element('operation-stop-row', list)
    assert.equal(shouldClearGeocoderFocus(row, ['.operation-list'], ['.operation-route-toolbar']), true)

    const toolbar = element('operation-route-toolbar', list)
    const btn = element('btn', toolbar)
    assert.equal(shouldClearGeocoderFocus(btn, ['.operation-list'], ['.operation-route-toolbar']), false)

    assert.equal(shouldClearGeocoderFocus(row, [], []), false)
    assert.equal(shouldClearGeocoderFocus(null, ['.operation-list'], []), false)
  })
})
