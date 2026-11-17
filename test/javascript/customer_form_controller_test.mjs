// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/controllers/v2/customer_form_controller.js', import.meta.url)
const tmpPath = path.join(os.tmpdir(), 'planner-customer-form.mjs')
const source = fs.readFileSync(srcPath, 'utf8').replace(
  'import { Controller } from "@hotwired/stimulus"\n\nexport default class extends Controller {',
  'class Controller {}\n\nexport default class extends Controller {'
)
fs.writeFileSync(tmpPath, source)
const { default: CustomerFormController } = await import(pathToFileURL(tmpPath).href)

function el (checked = false, className = '') {
  const classes = new Set(String(className).split(/\s+/).filter(Boolean))
  return {
    checked,
    classList: {
      toggle (name, force) {
        if (force) classes.add(name)
        else classes.delete(name)
      },
      contains (name) {
        return classes.has(name)
      }
    },
    dataset: {}
  }
}

describe('customer form external callback toggle', () => {
  it('shows the callback accordion when the enable checkbox is checked', () => {
    const checkbox = el(false)
    const container = el(false, 'd-none')
    const controller = new CustomerFormController()
    controller.element = {
      querySelector (selector) {
        if (selector === '#customer_enable_external_callback') return checkbox
        if (selector === '#external_callback_container') return container
        return null
      }
    }

    controller.syncExternalCallback()
    assert.equal(container.classList.contains('d-none'), true)

    checkbox.checked = true
    controller.syncExternalCallback()
    assert.equal(container.classList.contains('d-none'), false)
  })
})

describe('customer form Deliver v2 gate', () => {
  it('disables and clears operations_mobile when Cartoway Deliver is off', () => {
    const deliver = el(false)
    const mobile = el(true)
    const hiddenDeliver = { type: 'hidden', checked: false }
    const controller = new CustomerFormController()
    controller.element = {
      querySelector (selector) {
        if (selector === 'input[type="checkbox"]#customer_devices_deliver_enable') return deliver
        if (selector === 'input[type="checkbox"]#customer_operations_mobile') return mobile
        // Hidden field used to steal the id — must not win over the checkbox.
        if (selector === '#customer_devices_deliver_enable') return hiddenDeliver
        if (selector === '#customer_operations_mobile') return mobile
        return null
      }
    }

    controller.syncOperationsMobile()
    assert.equal(mobile.disabled, true)
    assert.equal(mobile.checked, false)

    deliver.checked = true
    controller.syncOperationsMobile()
    assert.equal(mobile.disabled, false)
  })
})
