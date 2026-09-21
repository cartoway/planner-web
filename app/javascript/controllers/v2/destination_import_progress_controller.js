// Copyright © Cartoway
// Poll /destinations.json and show import progress while a destination import job runs.

import { Controller } from '@hotwired/stimulus'
import { visit } from 'turbo/frame_promoted_visit'

const POLL_MS = 400
const COUNTER_KEYS = ['destinations', 'visits', 'stores', 'store_reloads', 'tags', 'plannings', 'geocoding']
const DISMISS_KEY = 'destination-import-dismissed-job-id'

export default class extends Controller {
  static targets = [
    'modal',
    'progressBar',
    'counters',
    'phase',
    'inqueue',
    'error',
    'attempts',
    'attemptsNumber',
    'dismiss'
  ]

  static values = {
    pollUrl: { type: String, default: '/destinations.json' },
    labels: { type: Object, default: {} }
  }

  connect () {
    this._timer = null
    this._job = null
    this._wasShowing = false
    this._dismissed = false
    this._closing = false
    this._abort = new AbortController()
    this._bsModal = null
    this._onHidden = () => this._afterHidden()
    if (this.hasModalTarget) {
      this.modalTarget.addEventListener('hidden.bs.modal', this._onHidden)
    }
    this._setDismissVisible(false)
    this.poll()
  }

  disconnect () {
    this._clearTimer()
    this._abort.abort()
    if (this.hasModalTarget && this._onHidden) {
      this.modalTarget.removeEventListener('hidden.bs.modal', this._onHidden)
    }
    if (this._bsModal) {
      // dispose avoids leftover backdrop without firing our hidden handler twice via visit
      this._closing = true
      this._bsModal.dispose()
      this._bsModal = null
    }
  }

  _clearTimer () {
    if (this._timer) {
      clearTimeout(this._timer)
      this._timer = null
    }
  }

  poll () {
    this._clearTimer()
    fetch(this.pollUrlValue, {
      headers: { Accept: 'application/json' },
      credentials: 'same-origin',
      signal: this._abort.signal
    })
      .then((response) => {
        if (!response.ok) throw new Error(response.statusText)
        return response.json()
      })
      .then((data) => this._onPoll(data))
      .catch((err) => {
        if (err.name === 'AbortError') return
        this._timer = setTimeout(() => this.poll(), POLL_MS * 2)
      })
  }

  _onPoll (data) {
    const job = data && data.import
    if (!job) {
      if (this._wasShowing && !this._dismissed && !this._closing) {
        this._closing = true
        this._hideModal()
        visit(window.location.href, { action: 'replace' })
      }
      return
    }

    // User closed a failed-import modal; keep it closed until dismiss is persisted.
    if (this._isDismissed(job)) return

    this._job = job
    this._wasShowing = true
    this._showModal()
    this._render(job)

    if (job.error) {
      this._showError(job.message)
      this._setDismissVisible(true)
      return
    }

    this._setDismissVisible(false)
    this._timer = setTimeout(() => this.poll(), POLL_MS)
  }

  _isDismissed (job) {
    if (this._dismissed && job.error) return true
    if (!job?.error || job.id == null) return false
    try {
      return sessionStorage.getItem(DISMISS_KEY) === String(job.id)
    } catch (e) {
      return false
    }
  }

  _markDismissed (job) {
    this._dismissed = true
    if (job?.id == null) return
    try {
      sessionStorage.setItem(DISMISS_KEY, String(job.id))
    } catch (e) { /* ignore quota / private mode */ }
  }

  _showModal () {
    if (!this.hasModalTarget) return
    if (!this._bsModal && window.bootstrap && window.bootstrap.Modal) {
      this._bsModal = window.bootstrap.Modal.getOrCreateInstance(this.modalTarget, {
        backdrop: 'static',
        keyboard: false
      })
    }
    this._bsModal?.show()
  }

  _setDismissVisible (visible) {
    if (!this.hasDismissTarget) return
    this.dismissTargets.forEach((el) => el.classList.toggle('d-none', !visible))
  }

  _hideModal () {
    this._bsModal?.hide()
    this._wasShowing = false
  }

  _render (job) {
    let progress = job.progress
    if (typeof progress === 'string') {
      try { progress = JSON.parse(progress) } catch (e) { progress = null }
    }
    progress = progress || {}

    if (this.hasInqueueTarget) {
      const queued = !progress.completed && progress.status !== 'working' && !job.attempts
      this.inqueueTarget.classList.toggle('d-none', !queued)
    }

    if (this.hasAttemptsTarget) {
      const showAttempts = !!job.attempts && !job.error
      this.attemptsTarget.classList.toggle('d-none', !showAttempts)
      if (showAttempts && this.hasAttemptsNumberTarget) {
        this.attemptsNumberTarget.textContent = job.attempts
      }
    }

    if (this.hasProgressBarTarget) {
      const value = progress.completed ? 100 : (Number(progress.first_progression) || 0)
      const showBar = progress.completed || (progress.status && progress.status !== 'queued')
      this.progressBarTarget.parentElement?.classList.toggle('d-none', !showBar)
      this.progressBarTarget.style.width = `${Math.min(100, Math.max(0, value))}%`
    }

    if (this.hasCountersTarget) {
      let any = false
      COUNTER_KEYS.forEach((key) => {
        const el = this.countersTarget.querySelector(`[data-counter="${key}"]`)
        if (!el) return
        if (progress[key]) {
          const countEl = el.querySelector('[data-count]')
          if (countEl) countEl.textContent = progress[key]
          el.classList.remove('d-none')
          const info = el.querySelector('.route-info')
          if (info) {
            if (progress.phase === key) {
              info.classList.remove('info')
              info.classList.add('primary')
            } else {
              info.classList.remove('primary')
              info.classList.add('info')
            }
          }
          any = true
        }
      })
      this.countersTarget.classList.toggle('d-none', !any)
    }

    if (this.hasPhaseTarget) {
      if (progress.phase) {
        const labels = this.labelsValue || {}
        this.phaseTarget.textContent = labels[progress.phase] || progress.phase
        this.phaseTarget.classList.remove('d-none')
      } else {
        this.phaseTarget.classList.add('d-none')
      }
    }

    if (this.hasErrorTarget && !job.error) {
      this.errorTarget.classList.add('d-none')
    }
  }

  _showError (message) {
    if (this.hasErrorTarget) {
      if (message) this.errorTarget.textContent = message
      this.errorTarget.classList.remove('d-none')
    }
    if (this.hasProgressBarTarget) this.progressBarTarget.parentElement?.classList.add('d-none')
    if (this.hasInqueueTarget) this.inqueueTarget.classList.add('d-none')
    if (this.hasCountersTarget) this.countersTarget.classList.add('d-none')
    if (this.hasPhaseTarget) this.phaseTarget.classList.add('d-none')
  }

  _dismissJob (job) {
    if (!job?.id || !job?.customer_id) return Promise.resolve()
    // Do not pass AbortSignal: dismiss must finish even if Turbo disconnects the controller.
    return fetch(`/api/0.1/customers/${job.customer_id}/job/${job.id}.json`, {
      method: 'DELETE',
      credentials: 'same-origin',
      headers: {
        Accept: 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
      }
    }).catch(() => {})
  }

  // Bootstrap data-bs-dismiss closes the modal; we dismiss the remembered job on hidden.
  _afterHidden () {
    if (this._closing) return
    this._closing = true
    this._clearTimer()
    const job = this._job
    this._markDismissed(job)
    this._wasShowing = false
    this._dismissJob(job).finally(() => {
      visit(window.location.href, { action: 'replace' })
    })
  }
}
