// Copyright © Cartoway
// Keep in sync with _syncPerPageFromListFrame in
// app/javascript/controllers/v2/destinations_index_controller.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

function resolvePerPage ({ activeOptionPerPage, framePerPage, urlPerPage }) {
  const next = (activeOptionPerPage || framePerPage || urlPerPage || '').toString().trim()
  return next || null
}

describe('destinations per_page sync after list frame load', () => {
  it('prefers the active dropdown option over stale frame/url values', () => {
    assert.equal(
      resolvePerPage({ activeOptionPerPage: '100', framePerPage: '25', urlPerPage: '50' }),
      '100'
    )
  })

  it('falls back to url when the active option is missing', () => {
    assert.equal(
      resolvePerPage({ activeOptionPerPage: null, framePerPage: null, urlPerPage: '50' }),
      '50'
    )
  })
})
