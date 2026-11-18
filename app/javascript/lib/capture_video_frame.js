// Copyright © Cartoway
// Snapshot a <video> frame to a JPEG File for mobile multi-shot capture.

import { jpegFileName, PHOTO_JPEG_QUALITY, PHOTO_MAX_EDGE, scaleToMaxEdge } from 'lib/compress_image'
import { canCaptureVideoFrame, waitForVideoFrame } from 'lib/video_frame_ready'

export { canCaptureVideoFrame, waitForVideoFrame }

export function captureVideoFrameToFile (video, name = `photo-${Date.now()}.jpg`) {
  if (!canCaptureVideoFrame(video)) {
    return Promise.reject(new Error('camera not ready'))
  }
  const { width, height } = scaleToMaxEdge(video.videoWidth, video.videoHeight, PHOTO_MAX_EDGE)
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d')
  if (!ctx) return Promise.reject(new Error('canvas unavailable'))
  ctx.drawImage(video, 0, 0, width, height)
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (!blob) {
        reject(new Error('capture failed'))
        return
      }
      resolve(new File([blob], jpegFileName(name), { type: 'image/jpeg' }))
    }, 'image/jpeg', PHOTO_JPEG_QUALITY)
  })
}
