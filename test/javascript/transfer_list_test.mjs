// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/controllers/v2/transfer_list_controller.js', import.meta.url)
const tmpPath = path.join(os.tmpdir(), 'planner-transfer-list.mjs')
const source = fs.readFileSync(srcPath, 'utf8').replace(
  'import { Controller } from "@hotwired/stimulus"\n\nconst ITEM_SELECTOR = ".transfer-list-item"\n\nexport default class extends Controller {',
  'class Controller {}\n\nconst ITEM_SELECTOR = ".transfer-list-item"\n\nexport default class extends Controller {'
)
fs.writeFileSync(tmpPath, source)
const { listValues, nextColumnKey, itemAfter, placeItem } = await import(pathToFileURL(tmpPath).href)

describe('transfer list values', () => {
  it('reads data-value from transfer-list items in DOM order', () => {
    const list = {
      children: [
        { matches: () => true, dataset: { value: 'ref' }, className: 'transfer-list-item' },
        { matches: () => true, dataset: { value: 'name' }, className: 'transfer-list-item' },
        { matches: () => true, dataset: { value: '' }, className: 'transfer-list-item' }
      ]
    }

    assert.deepEqual(listValues(list), ['ref', 'name'])
  })

  it('cycles to the next column key for 3-column layouts', () => {
    const columns = [
      { key: 'active' },
      { key: 'disabled' },
      { key: 'inactive' }
    ]

    assert.equal(nextColumnKey(columns, 'active'), 'disabled')
    assert.equal(nextColumnKey(columns, 'disabled'), 'inactive')
    assert.equal(nextColumnKey(columns, 'inactive'), 'active')
  })
})

function chip (left, top, width, height) {
  return {
    getBoundingClientRect () {
      return { left, top, width, height, right: left + width, bottom: top + height }
    }
  }
}

describe('transfer list reorder', () => {
  it('inserts a chip before the neighbour under the pointer instead of appending', () => {
    const a = chip(0, 0, 100, 24)
    const b = chip(110, 0, 100, 24)
    const c = chip(220, 0, 100, 24)
    const children = [a, b, c]
    const list = {
      querySelectorAll () { return children.filter((item) => item !== dragged) },
      insertBefore (item, before) {
        children.splice(children.indexOf(item), 1)
        children.splice(children.indexOf(before), 0, item)
      },
      appendChild (item) {
        children.splice(children.indexOf(item), 1)
        children.push(item)
      }
    }
    const dragged = a

    assert.equal(itemAfter(list, 250, 10), c)
    placeItem(list, a, 250, 10)
    assert.equal(children[0], b)
    assert.equal(children[1], a)
    assert.equal(children[2], c)
  })
})
