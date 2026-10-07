// Copyright © Cartoway
// Two-click confirmation with a short delay before the action runs.
// - Default: dispatches `confirm-click:confirmed` (bubbles) on the second valid click.
// - Optional url / form values: show a spinner and DELETE (or submit the form) instead.
import { Controller } from '@hotwired/stimulus'
import { renderStreamMessage, visit } from '@hotwired/turbo'

const ARMED_CLASS = 'confirm-click-armed'
const PENDING_CLASS = 'confirm-click-pending'
const SPINNER_HTML = '<i class="fa fa-spinner fa-spin fa-fw" aria-hidden="true"></i>'

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
    disarmAfter: { type: Number, default: 4000 },
    url: String,
    form: String
  }

  connect () {
    this.armedAt = null
    this.confirmReadyTimeout = null
    this.disarmTimeout = null
    this.originalHtml = null
    this.originalTitle = null
    this._destroyPending = false
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
    if (this._destroyPending) return

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
    if (this._hasDestroyTarget()) {
      this._startDestroy()
      return
    }

    // Listeners may set detail.handled = true (e.g. show spinner) so we must not restore trash HTML.
    const detail = { element: this.element, handled: false }
    this.dispatch('confirmed', { detail, bubbles: true })
    if (detail.handled) {
      this._clearArmedState({ restoreContent: false })
    } else {
      this.disarm()
    }
  }

  disarm () {
    if (this._destroyPending) return
    if (!this.element.classList.contains(ARMED_CLASS)) return
    this._clearArmedState({ restoreContent: true })
  }

  _clearArmedState ({ restoreContent }) {
    this._clearTimers()
    this.element.classList.remove(ARMED_CLASS, PENDING_CLASS, this.armedClassValue)
    if (this.baseClassValue) this.element.classList.add(this.baseClassValue)
    this.element.style.opacity = ''
    if (restoreContent) {
      if (this.originalHtml !== null) this.element.innerHTML = this.originalHtml
      this.element.title = this.originalTitle || ''
    }
    this.armedAt = null
  }

  _hasDestroyTarget () {
    return (this.hasUrlValue && !!this.urlValue) || (this.hasFormValue && !!this.formValue)
  }

  async _startDestroy () {
    this._destroyPending = true
    this.element.classList.remove(ARMED_CLASS, PENDING_CLASS, this.armedClassValue)
    if (this.baseClassValue) this.element.classList.add(this.baseClassValue)
    this.element.style.opacity = ''
    this.armedAt = null
    this.element.disabled = true
    this.element.innerHTML = SPINNER_HTML

    try {
      if (this.hasFormValue && this.formValue) {
        const form = document.getElementById(this.formValue)
        if (!form) throw new Error('destroy form missing')
        form.requestSubmit()
        return
      }
      await this._deleteUrl(this.urlValue)
    } catch (_error) {
      this._restoreAfterDestroy()
    }
  }

  async _deleteUrl (url) {
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    const res = await fetch(url, {
      method: 'DELETE',
      headers: {
        Accept: 'text/vnd.turbo-stream.html, text/html, application/xhtml+xml',
        'X-CSRF-Token': token || ''
      },
      credentials: 'same-origin',
      redirect: 'manual'
    })

    if (res.status === 303 || res.status === 302) {
      const location = res.headers.get('Location')
      if (location) {
        visit(location)
        return
      }
    }

    if (res.status === 204 || res.status === 200) {
      const contentType = res.headers.get('Content-Type') || ''
      if (contentType.includes('turbo-stream')) {
        renderStreamMessage(await res.text())
        return
      }
    }

    if (!res.ok && res.status !== 0) throw new Error(`HTTP ${res.status}`)
  }

  _restoreAfterDestroy () {
    this._destroyPending = false
    this.element.disabled = false
    if (this.originalHtml !== null) this.element.innerHTML = this.originalHtml
    this.element.title = this.originalTitle || ''
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
