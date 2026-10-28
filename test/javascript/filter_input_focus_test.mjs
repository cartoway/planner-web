// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it, beforeEach } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/lib/filter_input_focus.js', import.meta.url)
const tmpPath = path.join(os.tmpdir(), 'planner-filter-input-focus.mjs')
fs.writeFileSync(tmpPath, fs.readFileSync(srcPath))
const { captureFilterFocus, restoreFilterFocus, clearFilterFocus } = await import(pathToFileURL(tmpPath).href)

function fakeInput ({ id = 'v2-list-filters-search', name = 'q', value = 'abc', start = 3, end = 3 } = {}) {
  return {
    id,
    name,
    value,
    selectionStart: start,
    selectionEnd: end,
    focusCalls: 0,
    selection: null,
    focus () { this.focusCalls += 1 },
    setSelectionRange (s, e) { this.selection = [s, e] }
  }
}

describe('filter input focus', () => {
  beforeEach(() => {
    clearFilterFocus()
  })

  it('restores focus and caret after a Turbo replace', () => {
    const before = fakeInput({ start: 2, end: 2 })
    const after = fakeInput({ start: 0, end: 0 })
    globalThis.CSS = { escape: (s) => s }
    globalThis.document = {
      activeElement: before,
      getElementById (id) { return id === after.id ? after : null },
      querySelector () { return null }
    }

    captureFilterFocus(before)
    assert.equal(restoreFilterFocus(), true)
    assert.equal(after.focusCalls, 1)
    assert.deepEqual(after.selection, [2, 2])
  })

  it('ignores capture when the input is not focused', () => {
    const input = fakeInput()
    globalThis.CSS = { escape: (s) => s }
    globalThis.document = {
      activeElement: null,
      getElementById () { return input },
      querySelector () { return input }
    }

    captureFilterFocus(input)
    assert.equal(restoreFilterFocus(), false)
    assert.equal(input.focusCalls, 0)
  })
})
