// Copyright © Cartoway
// iOS navigation app preference: deep-link primary + Apple Maps fallback.

export const MOBILE_NAV_STORAGE_KEY = 'mobile_nav_app'
export const MOBILE_NAV_DEFAULT = 'benav'
export const MOBILE_NAV_APPS = ['apple', 'benav', 'google', 'waze']
export const MOBILE_NAV_FALLBACK_MS = 1200

export function normalizeMobileNavApp (value) {
  return MOBILE_NAV_APPS.includes(value) ? value : MOBILE_NAV_DEFAULT
}

function datasetKeyForApp (app) {
  return `nav${app.charAt(0).toUpperCase()}${app.slice(1)}`
}

// Returns { primary, fallback }. primary is null when Apple is selected (open fallback directly).
export function pickMobileNavTarget (dataset, preferred) {
  const app = normalizeMobileNavApp(preferred)
  const fallback = dataset?.navApple || null
  if (app === 'apple') return { primary: null, fallback }

  const primary = dataset?.[datasetKeyForApp(app)] || null
  if (!primary || primary === fallback) return { primary: null, fallback }
  return { primary, fallback }
}

// Try a deep link; if the page is still visible after FALLBACK_MS, open Apple Maps.
// Do not cancel on fleeting document.hidden (Control Center / notification shade).
export function openWithFallback (primary, fallback, {
  assign = (url) => { window.location.href = url },
  delayMs = MOBILE_NAV_FALLBACK_MS,
  now = () => Date.now(),
  isHidden = () => document.hidden,
  setTimer = (fn, ms) => window.setTimeout(fn, ms)
} = {}) {
  if (!primary && !fallback) return
  if (!primary || primary === fallback) {
    if (fallback) assign(fallback)
    return
  }
  const started = now()
  setTimer(() => {
    if (!isHidden() && now() - started < delayMs + 500) assign(fallback)
  }, delayMs)
  assign(primary)
}
