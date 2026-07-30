const STORAGE_KEY = 'turbo.tracked_frames_by_page'

function safeSessionStorage () {
  try {
    if (typeof window === 'undefined' || !window.sessionStorage) return null
    return window.sessionStorage
  } catch (_error) {
    return null
  }
}

function readStore (storage = safeSessionStorage()) {
  if (!storage) return {}

  try {
    const parsed = JSON.parse(storage.getItem(STORAGE_KEY) || '{}')
    return parsed && typeof parsed === 'object' ? parsed : {}
  } catch (_error) {
    return {}
  }
}

function writeStore (store, storage = safeSessionStorage()) {
  if (!storage) return

  try {
    storage.setItem(STORAGE_KEY, JSON.stringify(store))
  } catch (_error) {
  }
}

export function pageKeyForLocation (location, baseHref = typeof window !== 'undefined' ? window.location.href : 'http://localhost/') {
  const url = location instanceof URL ? location : new URL(String(location), baseHref)
  return `${url.pathname}${url.search}`
}

export function currentPageKey () {
  return pageKeyForLocation(typeof window !== 'undefined' ? window.location.href : 'http://localhost/')
}

export function loadTrackedFrameIdsForPage (key = currentPageKey(), storage = safeSessionStorage()) {
  const ids = readStore(storage)[key]
  return Array.isArray(ids) ? ids.map((id) => String(id)) : []
}

export function saveTrackedFrameIdsForPage (ids, key = currentPageKey(), storage = safeSessionStorage()) {
  const store = readStore(storage)
  store[key] = Array.from(new Set(Array.from(ids, (id) => String(id))))
  writeStore(store, storage)
}

export function restoreTrackedFrameIds (target, key = currentPageKey(), storage = safeSessionStorage()) {
  target.clear()
  loadTrackedFrameIdsForPage(key, storage).forEach((id) => target.add(id))
  return target
}

export function shouldRestoreTrackedFrames (event, navigationEntry = typeof performance !== 'undefined'
  ? performance.getEntriesByType('navigation')[0]
  : null) {
  if (event?.type === 'popstate') return true
  if (event?.type === 'pageshow' && event.persisted) return true
  return navigationEntry?.type === 'back_forward'
}
