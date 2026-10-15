// Copyright © Cartoway
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  nextPhotoModalIndex,
  photoUploadErrorMessage,
  resolveStopPhotosPanel
} from '../../app/javascript/lib/stop_photos_panel.js'

function el (className, kids = [], attrs = {}) {
  const node = {
    classList: {
      contains (name) { return String(className || '').split(/\s+/).includes(name) }
    },
    dataset: { ...attrs },
    children: kids,
    parent: null,
    closest (sel) {
      let cur = this
      while (cur) {
        if (sel === '.stop-documents' && cur.classList.contains('stop-documents')) return cur
        if (sel === '.stop-photos' && cur.classList.contains('stop-photos')) return cur
        cur = cur.parent
      }
      return null
    },
    querySelector (sel) {
      if (sel !== '.stop-photos') return null
      return this.children.find((c) => c.classList.contains('stop-photos')) || null
    }
  }
  kids.forEach((child) => { child.parent = node })
  return node
}

describe('stop_photos_panel', () => {
  it('resolves .stop-photos from a list remove/open button', () => {
    const photos = el('stop-photos', [], { url: '/stops/1/photos' })
    const remove = el('stop-photo-remove')
    const photo = el('stop-photo', [remove])
    const list = el('stop-documents-list', [photo])
    const docs = el('stop-documents', [photos, list])
    // Wire parents like a real DOM tree (el() only sets parent for direct kids).
    photos.parent = docs
    list.parent = docs
    photo.parent = list
    remove.parent = photo

    const panel = resolveStopPhotosPanel(remove)
    assert.ok(panel)
    assert.equal(panel.dataset.url, '/stops/1/photos')
    assert.equal(resolveStopPhotosPanel(panel), panel)
  })

  it('keeps modal index on the next photo after a delete', () => {
    assert.equal(nextPhotoModalIndex(0, 2), 0)
    assert.equal(nextPhotoModalIndex(1, 2), 1)
    assert.equal(nextPhotoModalIndex(2, 2), 1)
    assert.equal(nextPhotoModalIndex(0, 0), 0)
  })

  it('prefers errors[] then error sentence for 422 payloads', () => {
    assert.equal(
      photoUploadErrorMessage({ errors: ['Photos too many', 'Photos invalid'], error: 'ignored' }),
      'Photos too many\nPhotos invalid'
    )
    assert.equal(photoUploadErrorMessage({ error: 'Photos too many' }), 'Photos too many')
    assert.equal(photoUploadErrorMessage(null, 'fallback'), 'fallback')
  })
})
