// Copyright © Cartoway
// Keep in sync with destinations-sidebar expand/collapse in
// app/javascript/controllers/v2/destinations_index_controller.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

function expandDestinationsSidebar (sidebar) {
  if (!sidebar || !sidebar.classList.contains('slide-panel--collapsed')) return false
  sidebar.classList.remove('slide-panel--collapsed')
  return true
}

describe('destinations sidebar expand after form save', () => {
  it('reopens a collapsed destinations-sidebar', () => {
    const classes = new Set(['destinations-sidebar', 'slide-panel--collapsed'])
    const sidebar = {
      classList: {
        contains (name) { return classes.has(name) },
        remove (name) { classes.delete(name) }
      }
    }

    assert.equal(expandDestinationsSidebar(sidebar), true)
    assert.equal(classes.has('slide-panel--collapsed'), false)
  })

  it('is a no-op when the destinations-sidebar is already open', () => {
    const classes = new Set(['destinations-sidebar'])
    const sidebar = {
      classList: {
        contains (name) { return classes.has(name) },
        remove (name) { classes.delete(name) }
      }
    }

    assert.equal(expandDestinationsSidebar(sidebar), false)
    assert.equal(classes.has('slide-panel--collapsed'), false)
  })
})
