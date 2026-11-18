// Copyright © Cartoway
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { EventEmitter } from 'node:events'
import { canCaptureVideoFrame, waitForVideoFrame } from '../../app/javascript/lib/video_frame_ready.js'
import { formatCameraCount } from '../../app/javascript/lib/stop_photos_panel.js'
import { scaleToMaxEdge, PHOTO_MAX_EDGE } from '../../app/javascript/lib/compress_image.js'

function fakeVideo ({ width = 0, height = 0 } = {}) {
  const emitter = new EventEmitter()
  return {
    videoWidth: width,
    videoHeight: height,
    addEventListener (name, fn) { emitter.on(name, fn) },
    removeEventListener (name, fn) { emitter.off(name, fn) },
    emit (name) { emitter.emit(name) }
  }
}

describe('video_frame_ready', () => {
  it('allows a video frame capture only when dimensions are ready', () => {
    assert.equal(canCaptureVideoFrame(null), false)
    assert.equal(canCaptureVideoFrame({ videoWidth: 0, videoHeight: 720 }), false)
    assert.equal(canCaptureVideoFrame({ videoWidth: 1280, videoHeight: 720 }), true)
  })

  it('resolves waitForVideoFrame when metadata arrives', async () => {
    const video = fakeVideo()
    const pending = waitForVideoFrame(video, 500)
    video.videoWidth = 1280
    video.videoHeight = 720
    video.emit('loadedmetadata')
    await assert.doesNotReject(pending)
  })

  it('rejects waitForVideoFrame on timeout', async () => {
    const video = fakeVideo()
    await assert.rejects(waitForVideoFrame(video, 20), /camera not ready/)
  })

  it('scales native camera frames down before canvas snapshot', () => {
    const sized = scaleToMaxEdge(4032, 3024, PHOTO_MAX_EDGE)
    assert.equal(sized.width <= PHOTO_MAX_EDGE, true)
    assert.equal(sized.height <= PHOTO_MAX_EDGE, true)
    assert.equal(sized.width, PHOTO_MAX_EDGE)
  })
})

describe('formatCameraCount', () => {
  it('fills current and max placeholders', () => {
    assert.equal(formatCameraCount('%{current} / %{max}', 3, 10), '3 / 10')
    assert.equal(formatCameraCount(null, 0, 10), '0 / 10')
  })
})
