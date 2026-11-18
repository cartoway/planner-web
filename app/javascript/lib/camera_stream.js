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
