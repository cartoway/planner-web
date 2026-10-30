// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/lib/list_filter.js', import.meta.url)
const tmpPath = path.join(os.tmpdir(), 'planner-list-filter.mjs')
fs.writeFileSync(tmpPath, fs.readFileSync(srcPath))
const { normalizeFilterQuery, scheduleListFilter } = await import(pathToFileURL(tmpPath).href)

describe('list filter', () => {
  it('filters items across chunks and reports visible count', () => {
    const items = [
      { text: 'alpha', visible: true },
      { text: 'beta', visible: true },
      { text: 'alphabet', visible: true }
    ]
    const tasks = []
    let doneCount = null
    scheduleListFilter({
      items,
      query: ' alp ',
      getText: (r) => r.text,
      setVisible: (r, show) => { r.visible = show },
      onDone: (n) => { doneCount = n },
      chunkSize: 1,
      schedule: (fn) => tasks.push(fn)
    })
    while (tasks.length) tasks.shift()()
    assert.equal(normalizeFilterQuery(' alp '), 'alp')
    assert.equal(doneCount, 2)
    assert.equal(items[0].visible, true)
    assert.equal(items[1].visible, false)
    assert.equal(items[2].visible, true)
  })

  it('cancel stops a multi-chunk run so typing stays responsive', () => {
    const items = [{ text: 'a' }, { text: 'b' }, { text: 'c' }]
    const tasks = []
    let done = false
    const cancel = scheduleListFilter({
      items,
      query: 'a',
      getText: (r) => r.text,
      setVisible: () => {},
      onDone: () => { done = true },
      chunkSize: 1,
      schedule: (fn) => tasks.push(fn)
    })
    assert.equal(tasks.length, 1)
    tasks.shift()()
    cancel()
    assert.equal(tasks.length, 1)
    tasks.shift()()
    assert.equal(done, false)
  })
})
