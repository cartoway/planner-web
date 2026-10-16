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
  return status === '404' || status === '409'
}

function dropOnGone (storage, key, error) {
  if (key.startsWith('position_') && isGoneError(error)) delete storage[key]
}

const queue = {
  position_3: JSON.stringify({ id: 3, url: '/operations/1/routes/10/update_position' })
}
dropOnGone(queue, 'position_3', new Error('404'))
if (queue.position_3) throw new Error('expected 404 to drop queued position')

console.log('mobile_position_queue_test: ok')
