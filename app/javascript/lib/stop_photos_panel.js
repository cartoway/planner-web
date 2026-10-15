// Copyright © Cartoway
// Photos actions live under .stop-documents-list; upload URL is on sibling .stop-photos.

export function resolveStopPhotosPanel (el) {
  if (!el) return null
  if (el.classList && el.classList.contains('stop-photos')) return el
  const docs = typeof el.closest === 'function' ? el.closest('.stop-documents') : null
  if (docs) return docs.querySelector('.stop-photos')
  return typeof el.closest === 'function' ? el.closest('.stop-photos') : null
}

export function nextPhotoModalIndex (index, lengthAfterDelete) {
  if (lengthAfterDelete <= 0) return 0
  return Math.min(Math.max(0, index), lengthAfterDelete - 1)
}

// Prefer server `errors[]`, then `error` sentence, then fallback.
export function photoUploadErrorMessage (data, fallback = '') {
  if (data && Array.isArray(data.errors) && data.errors.length) {
    return data.errors.filter(Boolean).join('\n')
  }
  if (data && data.error) return String(data.error)
  return fallback
}
