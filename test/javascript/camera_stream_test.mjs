// Copyright © Cartoway
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { startCameraStream } from '../../app/javascript/lib/camera_stream.js'

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
