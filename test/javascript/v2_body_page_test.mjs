// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const src = new URL('../../app/javascript/lib/v2_body_page.js', import.meta.url)
const tmp = path.join(os.tmpdir(), 'planner-v2-body-page.mjs')
fs.writeFileSync(tmp, fs.readFileSync(src))
const { syncV2BodyPageFromMain } = await import(pathToFileURL(tmp).href)

describe('v2 body page', () => {
  it('copies marker attrs onto body after a turbo main navigation', () => {
    const attrs = {
      'data-controller': 'operations operations-v2',
      'data-action': 'show'
    }
    const body = {
      getAttribute (name) { return attrs[name] || null },
      setAttribute (name, value) { attrs[name] = value }
    }
    const marker = {
      getAttribute (name) {
        if (name === 'data-v2-body-controller') return 'destinations destinations-v2'
        if (name === 'data-v2-body-action') return 'index'
        return null
      }
    }
    const main = {
      querySelector (sel) {
        assert.equal(sel, '[data-v2-body-page]')
        return marker
      }
    }
    const doc = {
      body,
      getElementById (id) {
        assert.equal(id, 'main')
        return main
      }
    }

    syncV2BodyPageFromMain(doc)
    assert.equal(attrs['data-controller'], 'destinations destinations-v2')
    assert.equal(attrs['data-action'], 'index')
  })
})
