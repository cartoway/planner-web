// Copyright © Cartoway
// Shared MapLibre interaction presets.

/** Disable map pitch and bearing gestures (mouse, touch, keyboard rotation). */
export function disableMapPitchAndRotation (map) {
  if (!map) return

  map.dragRotate.disable()
  map.touchZoomRotate.disableRotation()
  map.touchPitch.disable()
  map.setMaxPitch(0)
  map.setMinPitch(0)
}
