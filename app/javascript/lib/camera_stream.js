// Copyright © Cartoway
// getUserMedia helper for the mobile in-page camera.

const CAMERA_CONSTRAINTS = {
  audio: false,
  video: {
    facingMode: { ideal: 'environment' },
    width: { ideal: 1920 },
    height: { ideal: 1080 }
  }
}

export function startCameraStream (constraints = CAMERA_CONSTRAINTS) {
  if (!navigator.mediaDevices?.getUserMedia) {
    return Promise.reject(new Error('getUserMedia unavailable'))
  }
  return navigator.mediaDevices.getUserMedia(constraints)
}

export function getVideoTrack (stream) {
  return stream?.getVideoTracks?.()[0] || null
}

// Torch capability is device/browser specific (often Android Chrome rear camera only).
export function cameraTorchSupported (track) {
  const caps = typeof track?.getCapabilities === 'function' ? track.getCapabilities() : null
  return !!(caps && Object.prototype.hasOwnProperty.call(caps, 'torch'))
}

export function setCameraTorch (track, on) {
  if (!track || typeof track.applyConstraints !== 'function') {
    return Promise.reject(new Error('torch unavailable'))
  }
  return track.applyConstraints({ advanced: [{ torch: !!on }] })
}
