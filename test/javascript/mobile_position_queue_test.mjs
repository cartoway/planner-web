// Assert stale GPS queue entries are dropped when the mobile URL changes.
// Run: node test/javascript/mobile_position_queue_test.mjs

function discardStalePositions (storage, currentUrl) {
  Object.keys(storage).forEach((key) => {
    if (!key.startsWith('position_')) return
    let item
    try {
      item = JSON.parse(storage[key])
    } catch (_err) {
      delete storage[key]
      return
    }
    if (!item || (currentUrl && item.url === currentUrl)) return
    delete storage[key]
  })
}

const storage = {
  position_1: JSON.stringify({ id: 1, url: '/operations/1/routes/10/update_position', coords: {} }),
  position_2: JSON.stringify({ id: 2, url: '/operations/2/routes/20/update_position', coords: {} }),
  stop_update_9: JSON.stringify({ id: 9, url: '/stops/1' })
}

discardStalePositions(storage, '/operations/2/routes/20/update_position')

if (storage.position_1) throw new Error('expected stale position_1 removed')
if (!storage.position_2) throw new Error('expected current position_2 kept')
if (!storage.stop_update_9) throw new Error('expected stop queue untouched')

function isGoneError (error) {
  const status = String(error && error.message)
  return status === '404' || status === '409' || status === '422' || status === '403'
}

function dropOnGone (storage, key, error) {
  if (!isGoneError(error)) return
  if (key.startsWith('position_') || key.startsWith('stop_update_') || key.startsWith('route_update_')) {
    delete storage[key]
  }
}

function discardCurrentPositions (storage, currentUrl) {
  Object.keys(storage).forEach((key) => {
    if (!key.startsWith('position_')) return
    let item
    try {
      item = JSON.parse(storage[key])
    } catch (_err) {
      delete storage[key]
      return
    }
    if (!item) {
      delete storage[key]
      return
    }
    if (!currentUrl || item.url === currentUrl) delete storage[key]
  })
}

const queue = {
  position_3: JSON.stringify({ id: 3, url: '/operations/1/routes/10/update_position' })
}
dropOnGone(queue, 'position_3', new Error('404'))
if (queue.position_3) throw new Error('expected 404 to drop queued position')

const closed = {
  position_4: JSON.stringify({ id: 4, url: '/operations/1/routes/10/update_position' })
}
dropOnGone(closed, 'position_4', new Error('422'))
if (closed.position_4) throw new Error('expected 422 (closed/expired) to drop queued position')

const missingStop = {
  stop_update_7: JSON.stringify({ id: 7, url: '/operation_stops/4602' })
}
dropOnGone(missingStop, 'stop_update_7', new Error('404'))
if (missingStop.stop_update_7) throw new Error('expected 404 to drop queued stop update')

const expiredTour = {
  position_5: JSON.stringify({ id: 5, url: '/operations/1/routes/10/update_position', coords: {} }),
  position_6: JSON.stringify({ id: 6, url: '/operations/2/routes/20/update_position', coords: {} }),
  stop_update_1: JSON.stringify({ id: 1, url: '/stops/1' })
}
discardCurrentPositions(expiredTour, '/operations/1/routes/10/update_position')
if (expiredTour.position_5) throw new Error('expected current-tour GPS dropped when expired')
if (!expiredTour.position_6) throw new Error('expected other-tour GPS kept')
if (!expiredTour.stop_update_1) throw new Error('expected stop queue untouched')

console.log('mobile_position_queue_test: ok')
