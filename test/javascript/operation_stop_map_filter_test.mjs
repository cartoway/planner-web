// Copyright © Cartoway
// Phase/query filter for operation stop list rows and map markers must stay aligned.
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

function matchesStopFilter (phase, label, { selectedPhase = 'all', query = '' } = {}) {
  const phaseOk = selectedPhase === 'all' || phase === 'depot' || phase === selectedPhase
  const queryOk = !query || String(label || '').toLowerCase().includes(query)
  return phaseOk && queryOk
}

const PHASE_COLORS = {
  delivered: '#1f9d55',
  failed: '#d64545',
  exception: '#7c3aed',
  current: '#25417c',
  late: '#f59e0b',
  upcoming: '#9ca3af'
}

function depotPhaseFromStatus (status) {
  const code = String(status || '').toLowerCase()
  if (code === 'rejected' || code === 'undelivered') return 'failed'
  if (code === 'exception') return 'exception'
  if (code === 'delivered' || code === 'finished') return 'delivered'
  if (code === 'intransit' || code === 'atstore' || code === 'inprocessing' || code === 'started') return 'current'
  return 'upcoming'
}

function depotStatusPaint (statuses) {
  const order = ['failed', 'exception', 'late', 'current', 'upcoming', 'delivered']
  const counts = Object.fromEntries(order.map((phase) => [phase, 0]))
  ;(statuses || []).forEach((status) => {
    counts[depotPhaseFromStatus(status)] += 1
  })
  const total = order.reduce((sum, phase) => sum + counts[phase], 0)
  if (!total) return null
  const present = order.filter((phase) => counts[phase] > 0)
  if (present.length === 1) return { solid: present[0] }
  let cursor = 0
  const parts = present.map((phase) => {
    const start = (cursor / total) * 360
    cursor += counts[phase]
    const end = (cursor / total) * 360
    return `${PHASE_COLORS[phase]} ${start}deg ${end}deg`
  })
  return { conic: `conic-gradient(${parts.join(', ')})` }
}

function uniqueDepotPlaces (features) {
  const places = new Map()
  features.forEach((feature) => {
    const coords = feature.geometry.coordinates
    const key = `${Number(coords[0]).toFixed(5)},${Number(coords[1]).toFixed(5)}`
    const place = places.get(key) || { statuses: [] }
    place.statuses.push(feature.properties.status)
    places.set(key, place)
  })
  return [...places.values()]
}

describe('operation stop map filter', () => {
  it('keeps only markers whose phase matches the selected chip', () => {
    assert.equal(matchesStopFilter('delivered', 'Alpha', { selectedPhase: 'delivered' }), true)
    assert.equal(matchesStopFilter('failed', 'Alpha', { selectedPhase: 'delivered' }), false)
    assert.equal(matchesStopFilter('depot', 'Depot', { selectedPhase: 'delivered' }), true)
    assert.equal(matchesStopFilter('upcoming', 'Alpha', { selectedPhase: 'all' }), true)
  })

  it('paints one depot marker as a proportional status pie', () => {
    const places = uniqueDepotPlaces([
      { geometry: { coordinates: [1.1, 48.2] }, properties: { status: 'finished' } },
      { geometry: { coordinates: [1.1, 48.2] }, properties: { status: 'finished' } },
      { geometry: { coordinates: [1.1, 48.2] }, properties: { status: 'atstore' } }
    ])
    assert.equal(places.length, 1)
    assert.deepEqual(depotStatusPaint(['finished', 'finished']), { solid: 'delivered' })
    assert.deepEqual(depotStatusPaint(['atstore']), { solid: 'current' })
    assert.equal(
      depotStatusPaint(places[0].statuses).conic,
      `conic-gradient(${PHASE_COLORS.current} 0deg 120deg, ${PHASE_COLORS.delivered} 120deg 360deg)`
    )
  })
})
