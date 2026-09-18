// Copyright © Cartoway
// Lat/lng field helpers for Maskito number masks (6 decimals, same as map sync).

const LAT_NAME = /\[lat\]/
const LNG_NAME = /\[lng\]/

export function isCoordFieldName (name) {
  const n = name || ""
  return LAT_NAME.test(n) || LNG_NAME.test(n)
}

export function isLatFieldName (name) {
  return LAT_NAME.test(name || "")
}

/** Params for maskitoNumber / maskitoParseNumber / maskitoStringifyNumber. */
export function maskitoCoordParams (name) {
  const lat = isLatFieldName(name)
  return {
    min: lat ? -90 : -180,
    max: lat ? 90 : 180,
    maximumFractionDigits: 6,
    thousandSeparator: "",
    minusSign: "-"
  }
}
