// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const src = new URL('../../app/javascript/lib/map_view_hash.js', import.meta.url)
const tmp = path.join(os.tmpdir(), 'planner-map-view-hash.mjs')
fs.writeFileSync(tmp, fs.readFileSync(src))
const { parseMapViewHash, formatMapViewHash, replaceMapViewHash } = await import(pathToFileURL(tmp).href)

describe('map view hash', () => {
  it('parses leaflet-style #zoom/lat/lng', () => {
    assert.deepEqual(parseMapViewHash('#12/48.85/2.35'), { zoom: 12, center: [2.35, 48.85] })
  })

  it('formats with leaflet hash precision and one zoom decimal', () => {
    assert.equal(formatMapViewHash(12, 48.8566, 2.3522), '#12/48.8566/2.3522')
    assert.equal(formatMapViewHash(12.37, 48.8566, 2.3522), '#12.4/48.8566/2.3522')
  })

  it('returns null for a form sidebar hash or junk', () => {
    assert.equal(parseMapViewHash('#visits'), null)
    assert.equal(parseMapViewHash(''), null)
  })

  it('replaces only the hash and keeps path plus query', () => {
    const loc = { pathname: '/destinations/42/edit', search: '?q=lyon', hash: '' }
    const calls = []
    const historyApi = {
      state: { formSidebar: true },
      replaceState (state, _title, url) { calls.push({ state, url }) }
    }
    replaceMapViewHash('#12/48.85/2.35', loc, historyApi)
    assert.deepEqual(calls, [{ state: { formSidebar: true }, url: '/destinations/42/edit?q=lyon#12/48.85/2.35' }])
  })
})
