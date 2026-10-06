// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const src = new URL('../../app/javascript/lib/form_sidebar_history.js', import.meta.url)
const tmp = path.join(os.tmpdir(), 'planner-form-sidebar-history.mjs')
fs.writeFileSync(tmp, fs.readFileSync(src))
const { formSidebarHistoryUpdate, formSidebarPageKey } = await import(pathToFileURL(tmp).href)

describe('form sidebar history', () => {
  it('pushes the form url when the sidebar opens from the list', () => {
    const update = formSidebarHistoryUpdate({
      currentHref: 'http://example.test/destinations?page=2',
      frameSrc: '/destinations/42/edit',
      listUrl: '/destinations?page=2',
      hasForm: true
    })
    assert.deepEqual(update, { type: 'push', url: '/destinations/42/edit', formSidebar: true })
  })

  it('does not push when the address bar already has the form url', () => {
    const update = formSidebarHistoryUpdate({
      currentHref: 'http://example.test/destinations/42/edit',
      frameSrc: '/destinations/42/edit',
      listUrl: '/destinations',
      hasForm: true
    })
    assert.equal(update, null)
  })

  it('restores the list url when the form closes', () => {
    const update = formSidebarHistoryUpdate({
      currentHref: 'http://example.test/destinations/42/edit',
      frameSrc: null,
      listUrl: '/destinations?page=2',
      hasForm: false
    })
    assert.deepEqual(update, { type: 'push', url: '/destinations?page=2', formSidebar: false })
  })

  it('ignores history updates triggered by popstate', () => {
    const update = formSidebarHistoryUpdate({
      currentHref: 'http://example.test/destinations',
      frameSrc: '/destinations/42/edit',
      listUrl: '/destinations',
      hasForm: true,
      fromPopstate: true
    })
    assert.equal(update, null)
  })

  it('builds a path+query key', () => {
    assert.equal(formSidebarPageKey('http://example.test/destinations/42/edit?include_past=1'), '/destinations/42/edit?include_past=1')
  })
})
