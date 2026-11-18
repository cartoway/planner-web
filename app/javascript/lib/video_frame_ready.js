// Copyright © Cartoway
// Pure helpers: detect when a <video> stream has usable frame dimensions.

export function canCaptureVideoFrame (video) {
  return Boolean(video && video.videoWidth > 0 && video.videoHeight > 0)
}

const READY_EVENTS = ['loadeddata', 'loadedmetadata', 'playing', 'resize']

// Wait until the stream has painted a frame (iOS/Android often report 0×0 briefly after play()).
export function waitForVideoFrame (video, timeoutMs = 2000) {
  if (canCaptureVideoFrame(video)) return Promise.resolve(video)
  if (!video) return Promise.reject(new Error('camera not ready'))

  return new Promise((resolve, reject) => {
    let settled = false
    const finish = (ok) => {
      if (settled) return
      settled = true
      globalThis.clearTimeout(timer)
      READY_EVENTS.forEach((name) => video.removeEventListener(name, onReady))
      if (ok) resolve(video)
      else reject(new Error('camera not ready'))
    }
    const onReady = () => {
      if (canCaptureVideoFrame(video)) finish(true)
    }
    const timer = globalThis.setTimeout(() => finish(false), timeoutMs)
    READY_EVENTS.forEach((name) => video.addEventListener(name, onReady))
    // Prefer the first decoded frame when the browser supports it.
    if (typeof video.requestVideoFrameCallback === 'function') {
      video.requestVideoFrameCallback(() => {
        if (canCaptureVideoFrame(video)) finish(true)
      })
    }
    onReady()
  })
}
