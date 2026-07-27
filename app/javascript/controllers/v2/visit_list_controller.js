// Copyright © Cartoway
// Visit list helpers: smooth reveal after append/reload, sync collapse-all header after add/remove.
import { Controller } from '@hotwired/stimulus'

const SCROLL_OFFSET_PX = 12
const REVEAL_CLASS = 'visit-fieldset--reveal'

export default class extends Controller {
  static values = {
    scrollToVisitId: { type: Number, default: 0 }
  }

  connect () {
    if (this.scrollToVisitIdValue > 0) {
      this.revealVisit(this.scrollToVisitIdValue)
    }
  }

  revealVisit (visitId) {
    const fieldset = this._fieldsetFor(visitId)
    if (fieldset) this.revealElement(fieldset)
  }

  revealElement (fieldset) {
    if (!fieldset) return
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this._smoothScrollTo(fieldset)
        if (!this._prefersReducedMotion()) this._playRevealTransition(fieldset)
      })
    })
  }

  syncHeader () {
    const count = this.element.querySelectorAll('fieldset.visit-fieldset').length
    const header = this.element.querySelector('#visits-header')
    if (count <= 1 && header) header.remove()
  }

  _fieldsetFor (visitId) {
    return this.element.querySelector(`#visit-fieldset-${visitId}`)
  }

  _smoothScrollTo (element) {
    const root = document.getElementById('destination-form-sidebar')
    if (!root) return

    const rootRect = root.getBoundingClientRect()
    const elRect = element.getBoundingClientRect()
    const targetTop = root.scrollTop + elRect.top - rootRect.top - SCROLL_OFFSET_PX

    if (typeof root.scrollTo === 'function') {
      root.scrollTo({ top: targetTop, behavior: this._prefersReducedMotion() ? 'auto' : 'smooth' })
    } else {
      root.scrollTop = targetTop
    }
  }

  _prefersReducedMotion () {
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches
  }

  _playRevealTransition (fieldset) {
    fieldset.classList.remove(REVEAL_CLASS)
    // Force reflow so re-adding the class replays the animation on repeated appends.
    void fieldset.offsetWidth
    fieldset.classList.add(REVEAL_CLASS)
    fieldset.addEventListener('animationend', () => {
      fieldset.classList.remove(REVEAL_CLASS)
    }, { once: true })
  }
}
