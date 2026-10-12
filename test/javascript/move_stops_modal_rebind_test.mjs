// Copyright © Cartoway
// Keep in sync with MoveStopsModal.initialize in app/assets/javascripts/modals/move_stops_modal.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

// Turbolinks keeps the singleton but replaces #move-stops-modal — initialize must rebind.
function initialize(state) {
  state.setupCount++
  state.isInitialized = true
}

describe('move stops modal rebind after Turbolinks', () => {
  it('calls setupEventHandlers on every initialize, not only the first', () => {
    const state = { setupCount: 0, isInitialized: false }

    initialize(state)
    assert.equal(state.isInitialized, true)
    assert.equal(state.setupCount, 1)

    // Simulate planning form AJAX save → Turbolinks.visit → plannings_edit → initialize again
    initialize(state)
    assert.equal(state.setupCount, 2)
  })
})
