// Copyright © Cartoway
// Keep in sync with freeze/unfreeze ownership in app/assets/javascripts/ajax.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

function isSameProgressDialog(dialog, other) {
  return !!(dialog && other && dialog.get(0) === other.get(0))
}

function fakeDialog(id) {
  const el = { id }
  return { get: () => el }
}

// Mirrors progressDialog(undefined) release + freezeProgressDialog stacking rules.
function simulatePollCycle(state, importDialog, optimizerDialog, optimizerActive) {
  // import has no job → progressDialog(undefined, importDialog)
  if (state.frozen && isSameProgressDialog(importDialog, state.frozenDialog)) {
    state.waiting--
    state.frozen = false
    state.frozenDialog = null
  }

  if (optimizerActive) {
    // progressDialog(job, optimizerDialog) → freeze once
    if (!state.frozen) {
      state.waiting++
      state.frozen = true
      state.frozenDialog = optimizerDialog
    }
  } else if (state.frozen && isSameProgressDialog(optimizerDialog, state.frozenDialog)) {
    // progressDialog(undefined, optimizerDialog) on success
    state.waiting--
    state.frozen = false
    state.frozenDialog = null
  }
}

describe('progress dialog waiting cursor', () => {
  it('does not stack beforeSendWaiting across optimizer polls when import has no job', () => {
    const importDialog = fakeDialog('import')
    const optimizerDialog = fakeDialog('optimizer')
    const state = { waiting: 0, frozen: false, frozenDialog: null }

    simulatePollCycle(state, importDialog, optimizerDialog, true)
    assert.equal(state.waiting, 1)

    simulatePollCycle(state, importDialog, optimizerDialog, true)
    simulatePollCycle(state, importDialog, optimizerDialog, true)
    assert.equal(state.waiting, 1)

    simulatePollCycle(state, importDialog, optimizerDialog, false)
    assert.equal(state.waiting, 0)
    assert.equal(state.frozen, false)
  })
})
