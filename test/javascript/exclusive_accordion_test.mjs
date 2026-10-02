// Copyright © Cartoway
// Keep in sync with app/javascript/lib/exclusive_accordion.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

const SLIDE_MS = 200

function pinDelta (headingTop, stickyTop = 0) {
  return headingTop - stickyTop
}

function isDetailsOpen (item) {
  return !!item.open
}

function isCollapseOpen (item, openClass = 'in') {
  return !!(item.panelClasses && item.panelClasses.includes(openClass))
}

describe('exclusive accordion', () => {
  it('uses a short slide duration', () => {
    assert.equal(SLIDE_MS, 200)
  })

  it('pins below a sticky top offset', () => {
    assert.equal(pinDelta(128, 48), 80)
    assert.equal(pinDelta(80, 0), 80)
    assert.equal(pinDelta(48, 48), 0)
  })

  it('detects open state for details and collapse modes', () => {
    assert.equal(isDetailsOpen({ open: true }), true)
    assert.equal(isDetailsOpen({ open: false }), false)
    assert.equal(isCollapseOpen({ panelClasses: ['in'] }), true)
    assert.equal(isCollapseOpen({ panelClasses: [] }), false)
  })
})
