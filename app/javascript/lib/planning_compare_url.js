// Copyright © Cartoway
export function planningCompareUrl (ids, refId) {
  const params = new URLSearchParams({ ids: ids.join(",") })
  if (refId != null && refId !== "") params.set("ref", String(refId))
  return `/plannings/compare?${params.toString()}`
}
