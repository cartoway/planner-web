// Copyright © Cartoway
// Two-click confirmation with a short delay before the action runs.
// Dispatches `confirm-click:confirmed` (bubbles) on the second valid click.
import { Controller } from '@hotwired/stimulus'

const ARMED_CLASS = 'confirm-click-armed'
const PENDING_CLASS = 'confirm-click-pending'

let documentListenerCount = 0

function disarmAllConfirmClickControllers (application) {
  document.querySelectorAll(`[data-controller~="confirm-click"].${ARMED_CLASS}`).forEach((element) => {
    application.getControllerForElementAndIdentifier(element, 'confirm-click')?.disarm()
  })
}

export default class extends Controller {
  static values = {
    waitMessage: String,
    confirmMessage: String,
    readyLabel: String,
    group: String,
    baseClass: { type: String, default: '' },
    armedClass: { type: String, default: 'btn-warning' },
    delay: { type: Number, default: 200 },
    disarmAfter: { type: Number, default: 4000 }
  }

  connect () {
    this.armedAt = null
    this.confirmReadyTimeout = null
    this.disarmTimeout = null
    this.originalHtml = null
    this.originalTitle = null
    this._onClick = this.click.bind(this)
    this.element.addEventListener('click', this._onClick)

    if (documentListenerCount === 0) {
      this._onDocumentClick = (event) => {
        if (!event.target.closest(`.${ARMED_CLASS}`)) {
          disarmAllConfirmClickControllers(this.application)
        }
      }
      document.addEventListener('click', this._onDocumentClick)
    }
    documentListenerCount++
  }

  disconnect () {
    this.element.removeEventListener('click', this._onClick)
    this.disarm()
    documentListenerCount--
    if (documentListenerCount <= 0 && this._onDocumentClick) {
      document.removeEventListener('click', this._onDocumentClick)
      this._onDocumentClick = null
      documentListenerCount = 0
    }
  }

  click (event) {
    event.preventDefault()
    event.stopPropagation()

    if (!this.element.classList.contains(ARMED_CLASS)) {
      this._disarmGroup()
      this._arm()
      return
    }

    if (this.element.classList.contains(PENDING_CLASS) ||
        Date.now() - (this.armedAt || 0) < this.delayValue) {
      return
    }

    this._clearTimers()
    this.dispatch('confirmed', { detail: { element: this.element }, bubbles: true })
    this.disarm()
  }

  disarm () {
    if (!this.element.classList.contains(ARMED_CLASS)) return

    this._clearTimers()
    this.element.classList.remove(ARMED_CLASS, PENDING_CLASS, this.armedClassValue)
    if (this.baseClassValue) this.element.classList.add(this.baseClassValue)
    this.element.style.opacity = ''

    if (this.originalHtml !== null) this.element.innerHTML = this.originalHtml
    this.element.title = this.originalTitle || ''
    this.armedAt = null
  }

  _arm () {
    this.originalHtml = this.element.innerHTML
    this.originalTitle = this.element.title || ''

    this.element.classList.add(ARMED_CLASS, PENDING_CLASS, this.armedClassValue)
    if (this.baseClassValue) this.element.classList.remove(this.baseClassValue)
    this.element.style.opacity = '0.55'
    this.element.title = this.waitMessageValue || ''
    this.armedAt = Date.now()

    this.confirmReadyTimeout = window.setTimeout(() => {
      this.element.classList.remove(PENDING_CLASS)
      this.element.style.opacity = ''
      if (this.hasReadyLabelValue) {
        this.element.innerHTML = this.readyLabelValue
      }
      this.element.title = this.confirmMessageValue || ''
    }, this.delayValue)

    this.disarmTimeout = window.setTimeout(() => {
      this.disarm()
    }, this.disarmAfterValue)
  }

  _disarmGroup () {
    if (!this.hasGroupValue) return

    document.querySelectorAll(`[data-confirm-click-group-value="${CSS.escape(this.groupValue)}"]`).forEach((element) => {
      if (element === this.element) return
      this.application.getControllerForElementAndIdentifier(element, 'confirm-click')?.disarm()
    })
  }

  _clearTimers () {
    window.clearTimeout(this.confirmReadyTimeout)
    window.clearTimeout(this.disarmTimeout)
    this.confirmReadyTimeout = null
    this.disarmTimeout = null
  }
}
