// Copyright © Cartoway
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  PHOTO_MAX_EDGE,
  compressImage,
  compressImages,
  isCompressibleImage,
  jpegFileName,
  scaleToMaxEdge
} from '../../app/javascript/lib/compress_image.js'

function mockCanvasCompress (byteSize = 40 * 1024) {
  globalThis.createImageBitmap = async () => ({
    width: 4032,
    height: 3024,
    close () {}
  })
  globalThis.document = {
    createElement () {
      return {
        width: 0,
        height: 0,
        getContext () {
          return { drawImage () {} }
        },
        toBlob (cb, type) {
          cb(new Blob([new Uint8Array(byteSize)], { type }))
        }
      }
    }
  }
}

describe('compress_image', () => {
  it('scales the longest edge down and leaves smaller images alone', () => {
    assert.deepEqual(scaleToMaxEdge(4000, 3000, 1920), { width: 1920, height: 1440 })
    assert.deepEqual(scaleToMaxEdge(800, 600, 1920), { width: 800, height: 600 })
    assert.equal(PHOTO_MAX_EDGE, 1920)
  })

  it('normalizes filenames to .jpg', () => {
    assert.equal(jpegFileName('proof.HEIC'), 'proof.jpg')
    assert.equal(jpegFileName('a.b.png'), 'a.b.jpg')
    assert.equal(jpegFileName(''), 'photo.jpg')
  })

  it('treats iPhone HEIC picks (and empty MIME) as compressible', () => {
    assert.equal(isCompressibleImage(new File([], 'IMG_001.HEIC', { type: 'image/heic' })), true)
    assert.equal(isCompressibleImage(new File([], 'IMG_001.HEIC', { type: '' })), true)
    assert.equal(isCompressibleImage(new File([], 'notes.txt', { type: '' })), false)
  })

  it('compresses a large bitmap to a smaller jpeg file', async () => {
    const source = new File([new Uint8Array(600 * 1024).fill(7)], 'big.png', { type: 'image/png' })
    mockCanvasCompress()

    const out = await compressImage(source)
    assert.equal(out.type, 'image/jpeg')
    assert.equal(out.name, 'big.jpg')
    assert.ok(out.size < source.size)

    const many = await compressImages([source])
    assert.equal(many.length, 1)
    assert.equal(many[0].name, 'big.jpg')
  })

  it('converts HEIC to JPEG even when the jpeg blob is not smaller', async () => {
    const heic = new File([new Uint8Array(30 * 1024)], 'IMG_9.HEIC', { type: 'image/heic' })
    mockCanvasCompress(40 * 1024)

    const out = await compressImage(heic)
    assert.equal(out.type, 'image/jpeg')
    assert.equal(out.name, 'IMG_9.jpg')
  })

  it('skips already-small jpegs', async () => {
    const small = new File([new Uint8Array(20 * 1024)], 'ok.jpg', { type: 'image/jpeg' })
    const out = await compressImage(small)
    assert.equal(out, small)
  })
})
