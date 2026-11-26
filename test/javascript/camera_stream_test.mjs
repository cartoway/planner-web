// Copyright © Cartoway
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  cameraTorchSupported,
  getVideoTrack,
  setCameraTorch,
  startCameraStream
} from '../../app/javascript/lib/camera_stream.js'

describe('startCameraStream', () => {
  it('rejects when getUserMedia is unavailable', async () => {
    const previous = globalThis.navigator
    Object.defineProperty(globalThis, 'navigator', {
      configurable: true,
      value: { mediaDevices: undefined }
    })
    try {
      await assert.rejects(startCameraStream(), /getUserMedia unavailable/)
    } finally {
      Object.defineProperty(globalThis, 'navigator', {
        configurable: true,
        value: previous
      })
    }
  })
})

describe('camera torch', () => {
  it('reads the first video track and toggles torch when supported', async () => {
    const constraints = []
    const track = {
      getCapabilities: () => ({ torch: true }),
      applyConstraints: async (value) => { constraints.push(value) }
    }
    const stream = { getVideoTracks: () => [track] }

    assert.equal(getVideoTrack(stream), track)
    assert.equal(cameraTorchSupported(track), true)
    await setCameraTorch(track, true)
    assert.deepEqual(constraints[0], { advanced: [{ torch: true }] })
    await setCameraTorch(track, false)
    assert.deepEqual(constraints[1], { advanced: [{ torch: false }] })
  })

  it('reports unsupported when torch capability is missing', () => {
    assert.equal(cameraTorchSupported({ getCapabilities: () => ({}) }), false)
    assert.equal(cameraTorchSupported(null), false)
  })
})
