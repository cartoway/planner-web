// Copyright © Cartoway
// Pure helper for Tom Select body-portaled dropdown flip (see v2/tom_select_controller.js).

export function shouldOpenTomSelectUp (spaceBelow, spaceAbove, preferredMax = 260) {
  const need = Math.min(preferredMax, 160)
  return spaceBelow < need && spaceAbove > spaceBelow
}
