// Copyright © Cartoway
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  MOBILE_NAV_DEFAULT,
  normalizeMobileNavApp,
  openWithFallback,
  pickMobileNavTarget
} from '../../app/javascript/lib/mobile_nav.js'

const urls = {
  navApple: 'http://maps.apple.com/?daddr=48.85,2.35',
  navBenav: 'benav://?cmd=abc',
  navGoogle: 'comgooglemaps://?daddr=48.85,2.35&directionsmode=driving',
  navWaze: 'waze://?ll=48.85,2.35&navigate=yes'
}

describe('mobile_nav', () => {
  it('defaults unknown prefs to benav and opens that deep link with Apple fallback', () => {
    assert.equal(normalizeMobileNavApp('nope'), MOBILE_NAV_DEFAULT)
    assert.deepEqual(pickMobileNavTarget(urls, null), {
      primary: urls.navBenav,
      fallback: urls.navApple
    })
  })

  it('opens Apple Maps directly when selected', () => {
    assert.deepEqual(pickMobileNavTarget(urls, 'apple'), {
      primary: null,
      fallback: urls.navApple
    })
  })

  it('picks google and waze deep links with Apple Maps fallback', () => {
    assert.deepEqual(pickMobileNavTarget(urls, 'google'), {
      primary: urls.navGoogle,
      fallback: urls.navApple
    })
    assert.deepEqual(pickMobileNavTarget(urls, 'waze'), {
      primary: urls.navWaze,
      fallback: urls.navApple
    })
  })

  it('openWithFallback assigns primary then fallback only if still visible', () => {
    const assigned = []
    let hidden = false
    let tick = null
    openWithFallback(urls.navBenav, urls.navApple, {
      assign: (url) => assigned.push(url),
      delayMs: 10,
      now: () => 0,
      isHidden: () => hidden,
      setTimer: (fn) => { tick = fn }
    })
    assert.deepEqual(assigned, [urls.navBenav])
    tick()
    assert.deepEqual(assigned, [urls.navBenav, urls.navApple])

    assigned.length = 0
    hidden = true
    openWithFallback(urls.navWaze, urls.navApple, {
      assign: (url) => assigned.push(url),
      delayMs: 10,
      now: () => 0,
      isHidden: () => hidden,
      setTimer: (fn) => { tick = fn }
    })
    tick()
    assert.deepEqual(assigned, [urls.navWaze])
  })
})
