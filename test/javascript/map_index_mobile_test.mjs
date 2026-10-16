// Copyright © Cartoway
// Keep in sync with app/javascript/lib/map_index_mobile.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  applyMobileMapPane,
  isMapIndexMobileLayout,
  mapIndexFlyToPadding
} from '../../app/javascript/lib/map_index_mobile.js'

function rect (left, top, width, height) {
  return {
    left,
    top,
    right: left + width,
    bottom: top + height,
    width,
    height
  }
}

describe('map index mobile helpers', () => {
  it('detects mobile layout only when panes exist and media matches', () => {
    const layout = {
      querySelector (sel) {
        return sel === '.v2-map-index-mobile-panes' ? {} : null
      }
    }
    assert.equal(isMapIndexMobileLayout(layout, () => ({ matches: true })), true)
    assert.equal(isMapIndexMobileLayout(layout, () => ({ matches: false })), false)
    assert.equal(isMapIndexMobileLayout({ querySelector: () => null }, () => ({ matches: true })), false)
  })

  it('switches to the map pane and updates tab buttons', () => {
    const classes = new Set(['is-mobile-pane-list'])
    const layout = {
      classList: {
        contains (name) { return classes.has(name) },
        toggle (name, force) {
          if (force) classes.add(name)
          else classes.delete(name)
        }
      }
    }
    const btn = {
      dataset: { pane: 'map' },
      classList: { toggle () {} },
      setAttribute () {}
    }
    assert.equal(applyMobileMapPane(layout, [btn]), true)
    assert.equal(classes.has('is-mobile-pane-map'), true)
    assert.equal(classes.has('is-mobile-pane-list'), false)
    assert.equal(applyMobileMapPane(layout, [btn]), false)
  })

  it('does not treat a full-width list as left padding on mobile', () => {
    const layoutEl = { getBoundingClientRect: () => rect(0, 0, 390, 700) }
    const leftSidebar = {
      classList: { contains: () => false },
      getBoundingClientRect: () => rect(0, 48, 390, 652)
    }
    const mobile = mapIndexFlyToPadding({ layoutEl, leftSidebar, mobile: true })
    assert.deepEqual(mobile, { top: 48, bottom: 48, left: 48, right: 48 })

    const desktop = mapIndexFlyToPadding({ layoutEl, leftSidebar, mobile: false })
    assert.ok(desktop.left > 300, 'desktop still pads for the list overlay')
  })
})
