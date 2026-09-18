// Copyright © Cartoway
// Field classification for v2 schedule inputs (Maskito applies the actual mask).

const CLOCK_NAME = /\[(time_window_start(_[12])?|time_window_end(_[12])?|service_time_start|service_time_end|rest_start|rest_stop)\]/
const DURATION_NAME = /\[(duration|work_time|rest_duration|rest_lapse|max_ride_duration)\]/

export function isScheduleTimeName (name) {
  const n = name || ""
  return CLOCK_NAME.test(n) || DURATION_NAME.test(n)
}

/** @returns {{ seconds: boolean, clock: boolean }} */
export function fieldOptions (name) {
  const n = name || ""
  return {
    seconds: /\[duration\]/.test(n),
    clock: CLOCK_NAME.test(n)
  }
}

/** Params for maskitoTime / maskitoParseTime / maskitoStringifyTime. */
export function maskitoTimeParams (name) {
  const { seconds, clock } = fieldOptions(name)
  return {
    mode: seconds ? "HH:MM:SS" : "HH:MM",
    timeSegmentMaxValues: { hours: clock ? 23 : 99 },
    step: 1
  }
}
