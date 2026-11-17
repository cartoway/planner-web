// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/controllers/v2/transfer_list_controller.js', import.meta.url)
const tmpPath = path.join(os.tmpdir(), 'planner-transfer-list.mjs')
const source = fs.readFileSync(srcPath, 'utf8')
  .replace('import { Controller } from "@hotwired/stimulus"\n', '')
  .replace('import { showToast } from "lib/toast"\n', 'const showToast = () => null\n')
  .replace(
    'const ITEM_SELECTOR = ".transfer-list-item"\n\nexport default class extends Controller {',
    'class Controller {}\n\nconst ITEM_SELECTOR = ".transfer-list-item"\n\nexport default class extends Controller {'
  )
fs.writeFileSync(tmpPath, source)
const transferListModule = await import(pathToFileURL(tmpPath).href)
const { listValues, nextColumnKey, itemAfter, placeItem, syncItemHiddenInput } = transferListModule
const TransferListController = transferListModule.default

if (typeof globalThis.Event !== 'function') {
  globalThis.Event = class Event {
    constructor (type, init = {}) {
      this.type = type
      this.bubbles = !!init.bubbles
    }
  }
}

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

describe('transfer list form sync', () => {
  it('bubbles a change event so dirty-form-submit can show the save bar', () => {
    let received = null
    const controller = new TransferListController()
    controller.element = {
      dispatchEvent (event) {
        received = event
        return true
      }
    }
    controller.notifyFormChange()
    assert.equal(received.type, 'change')
    assert.equal(received.bubbles, true)
  })

  it('sets a hidden input name that follows the destination column', () => {
    const item = {
      dataset: { value: 'plannings' },
      _hiddenInputs: [{ type: 'hidden', name: 'role[spaces_active][]', value: 'plannings' }],
      querySelectorAll () {
        return [{
          remove: () => { this._hiddenInputs = [] }
        }]
      },
      appendChild (node) {
        this._hiddenInputs.push(node)
      }
    }

    syncItemHiddenInput(item, 'role[spaces_disabled][]')
    assert.equal(item._hiddenInputs.length, 1)
    assert.equal(item._hiddenInputs[0].name, 'role[spaces_disabled][]')
    assert.equal(item._hiddenInputs[0].value, 'plannings')

    syncItemHiddenInput(item, '')
    assert.equal(item._hiddenInputs.length, 0)
  })
})

describe('transfer list min active', () => {
  it('blocks emptying the active column when minActiveItems is 1', () => {
    const controller = new TransferListController()
    const active = { dataset: { inactive: 'false' }, querySelectorAll: () => [{ dataset: { value: 'ortools' } }] }
    const inactive = { dataset: { inactive: 'true' }, querySelectorAll: () => [] }
    controller.minActiveItemsValue = 1
    controller.listTargets = [active, inactive]

    assert.equal(controller.wouldViolateMinActive(active, inactive, 1), true)
    assert.equal(controller.wouldViolateMinActive(inactive, active, 1), false)
    assert.equal(controller.wouldViolateMinActive(active, inactive, 0), false)
  })
})

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
