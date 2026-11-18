// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/controllers/v2/workspace_guard_controller.js', import.meta.url)
const raw = fs.readFileSync(srcPath, 'utf8')
  .replace(/import \{ Controller \} from "@hotwired\/stimulus"/, 'class Controller {}')
  .replace(/export default class extends Controller/, 'export class WorkspaceGuardController extends Controller')

const tmpPath = path.join(os.tmpdir(), `planner-workspace-guard-${process.pid}.mjs`)
fs.writeFileSync(tmpPath, raw)
const {
  isMutatingMethod,
  isSameOrigin,
  isWorkspaceChangedResponse,
  HEADER,
  CHANGED_HEADER
} = await import(pathToFileURL(tmpPath).href)

describe('workspace guard', () => {
  it('treats only non-GET/HEAD as mutating', () => {
    assert.equal(isMutatingMethod('GET'), false)
    assert.equal(isMutatingMethod('HEAD'), false)
    assert.equal(isMutatingMethod('POST'), true)
    assert.equal(HEADER, 'X-Cartoway-Workspace')
    assert.equal(CHANGED_HEADER, 'X-Cartoway-Workspace-Changed')
  })

  it('only treats same-origin URLs as in-app', () => {
    const origin = 'https://planner.example'
    assert.equal(isSameOrigin('/workspace/switch', origin), true)
    assert.equal(isSameOrigin('https://planner.example/a', origin), true)
    assert.equal(isSameOrigin('https://cdn.example/x.js', origin), false)
  })

  it('detects workspace-changed responses via dedicated header only', () => {
    const headers = new Map([[CHANGED_HEADER, '1']])
    assert.equal(isWorkspaceChangedResponse({ headers: { get: (k) => headers.get(k) } }), true)
    assert.equal(isWorkspaceChangedResponse({ headers: { get: () => null }, status: 409 }), false)
  })
})
