import { Controller } from '@hotwired/stimulus'
import { ExclusiveAccordion } from 'lib/exclusive_accordion'
import { compressImages } from 'lib/compress_image'
import { nextPhotoModalIndex, photoUploadErrorMessage, resolveStopPhotosPanel } from 'lib/stop_photos_panel'

const CONFIRM_DELAY = 200
const CONFIRM_DISARM_AFTER = 4000
const PHOTO_DB = 'planner-mobile-photos'
const PHOTO_STORE = 'pending'

// Driver route screen: status, photos, signature and GPS.
// Offline writes stay in localStorage / IndexedDB and flush through the service worker.
export default class extends Controller {
  static values = { positionUrl: String }

  connect () {
    this._dead = false
    this.positionTimer = null
    this.photoModalItems = []
    this.photoModalIndex = 0
    this.photoModalPanel = null
    this.signaturePanel = null
    this.stopsAccordion = null
    this.onClick = this.onClick.bind(this)
    this.onChange = this.onChange.bind(this)
    this.onOnline = this.onOnline.bind(this)
    this.onServiceMessage = this.onServiceMessage.bind(this)
    this.element.addEventListener('click', this.onClick)
    this.element.addEventListener('change', this.onChange)
    window.addEventListener('online', this.onOnline)
    this.bindSignatureCanvas()
    this.registerServiceWorker()
    // Drop GPS queued for another operation/route — otherwise SW replays the old URL forever.
    this.discardStalePositions()
    if (sessionStorage.getItem('tracking_value') !== 'false') this.startTracking()
    this.flushPending()
  }

  disconnect () {
    this._dead = true
    this.stopTracking()
    this.stopsAccordion?.destroy()
    this.stopsAccordion = null
    this.element.removeEventListener('click', this.onClick)
    this.element.removeEventListener('change', this.onChange)
    window.removeEventListener('online', this.onOnline)
    if ('serviceWorker' in navigator) navigator.serviceWorker.removeEventListener('message', this.onServiceMessage)
  }

  toggleTracking (event) {
    const enabled = event.target.checked
    sessionStorage.setItem('tracking_value', enabled ? 'true' : 'false')
    if (enabled) this.startTracking()
    else this.stopTracking()
  }

  ensureStopsAccordion () {
    if (this.stopsAccordion) return this.stopsAccordion
    const root = this.element.querySelector('#accordion')
    if (!root) return null
    this.stopsAccordion = new ExclusiveAccordion({
      root,
      itemSelector: '.panel',
      panelSelector: '.panel-collapse',
      headingSelector: '[data-toggle="collapse"]',
      stickyTopSelector: '.mobile_header',
      mode: 'collapse',
      openClass: 'in'
    })
    return this.stopsAccordion
  }

  startTracking () {
    if (this.positionTimer) return
    this.sendCurrentPosition()
    this.positionTimer = window.setInterval(() => this.sendCurrentPosition(), 60 * 1000)
  }

  stopTracking () {
    if (!this.positionTimer) return
    window.clearInterval(this.positionTimer)
    this.positionTimer = null
  }

  sendCurrentPosition () {
    if (sessionStorage.getItem('tracking_value') === 'false') return
    if (!navigator.geolocation || !this.positionUrlValue) return
    navigator.geolocation.getCurrentPosition((position) => {
      if (this._dead) return
      const { latitude, longitude, accuracy, altitude, heading, speed } = position.coords
      const body = {
        latitude,
        longitude,
        positioned_at: new Date().toISOString()
      }
      // Some WebViews report "unknown" as ±Number.MAX_VALUE (finite but out of range).
      if (this.saneSensor(accuracy, 0, 100000)) body.accuracy = accuracy
      if (this.saneSensor(altitude, -1000, 20000)) body.altitude = altitude
      if (this.saneSensor(heading, 0, 360)) body.heading = heading
      if (this.saneSensor(speed, 0, 1000)) body.speed = speed
      if (!navigator.onLine) {
        this.queuePosition(body)
        return
      }
      this.patchJson(this.positionUrlValue, body).catch((error) => {
        // 404/409: route gone — never queue, would loop forever on a dead URL.
        if (this._dead || this.isGoneError(error)) return
        this.queuePosition(body)
      })
    }, () => {}, { enableHighAccuracy: true, maximumAge: 30_000, timeout: 20_000 })
  }

  // GPS points bound to another mobile URL must not keep PATCHing after navigation.
  discardStalePositions () {
    const current = this.positionUrlValue
    Object.keys(localStorage).forEach((key) => {
      if (!key.startsWith('position_')) return
      const item = this.readStored(key)
      if (!item || (current && item.url === current)) return
      localStorage.removeItem(key)
    })
    this.postToWorker('CLEAR_STALE_POSITIONS', { url: current })
  }

  clearQueuedPosition (id) {
    if (id == null) return
    localStorage.removeItem(`position_${id}`)
  }

  queuePosition (body) {
    const item = { id: Date.now(), url: this.positionUrlValue, coords: body }
    this.showPending()
    this.postToWorker('STORE_POSITION', item)
    this.localSet(`position_${item.id}`, item)
    this.registerSync('sync-positions')
  }

  onClick (event) {
    const target = event.target
    if (target.closest('.no-toggle')) event.stopPropagation()

    if (target.closest('[data-toggle="collapse"]') && !target.closest('.no-toggle, .stop-status-reset, #quick-status, .radiobtn')) {
      const heading = target.closest('[data-toggle="collapse"]')
      const panel = document.querySelector(heading.getAttribute('href'))
      const item = panel?.closest('.panel')
      const accordion = this.ensureStopsAccordion()
      if (item && accordion) {
        event.preventDefault()
        accordion.toggle(item)
      }
      return
    }

    const statusButton = target.closest('.radiobtn a, #quick-status')
    if (statusButton) {
      event.preventDefault()
      event.stopPropagation()
      const panel = statusButton.closest('.panel')
      if (panel) this.changeStatus(panel, statusButton.dataset.title || '', statusButton.dataset.toggle)
      return
    }

    const reset = target.closest('.stop-status-reset')
    if (reset) {
      event.preventDefault()
      event.stopPropagation()
      this.onStatusReset(reset)
      return
    }

    const transferToggle = target.closest('.route-select > .dropdown-toggle')
    if (transferToggle) {
      event.preventDefault()
      event.stopPropagation()
      this.toggleTransferDropdown(transferToggle)
      return
    }

    const transferLink = target.closest('.send_to_route')
    if (transferLink) {
      event.preventDefault()
      event.stopPropagation()
      this.transferStop(transferLink)
      return
    }

    // Close transfer dropdown on outside click
    if (!target.closest('.route-select.dropdown')) this.closeTransferDropdowns()

    const nav = target.closest('.mobile-nav-link')
    if (nav && nav.dataset.navPrimary) {
      event.preventDefault()
      this.openNavigation(nav)
      return
    }

    if (target.closest('.actual_quantities-edit')) {
      event.preventDefault()
      event.stopPropagation()
      this.toggleQuantityEdit(target.closest('.actual_quantities'))
      return
    }

    if (target.closest('.stop-documents-toggle')) {
      event.preventDefault()
      event.stopPropagation()
      const docs = target.closest('.stop-documents-accordion')
      const panel = docs && docs.querySelector('.stop-documents-panel')
      if (panel) panel.classList.toggle('d-none')
      return
    }

    if (target.closest('.stop-photo-open')) {
      event.preventDefault()
      event.stopPropagation()
      this.openPhoto(target.closest('.stop-photo-open'))
      return
    }

    if (target.closest('.stop-photo-remove')) {
      event.preventDefault()
      event.stopPropagation()
      const button = target.closest('.stop-photo-remove')
      this.deletePhoto(resolveStopPhotosPanel(button), button.dataset.url)
      return
    }

    if (target.closest('.stop-photo-modal-close')) this.closePhoto()
    else if (target.closest('.stop-photo-modal-prev')) this.stepPhoto(-1)
    else if (target.closest('.stop-photo-modal-next')) this.stepPhoto(1)
    else if (target.closest('.stop-photo-modal-delete')) this.deleteModalPhoto()
    else if (target.closest('.stop-signature-open')) this.openSignature(target.closest('.stop-signature'))
    else if (target.closest('.stop-signature-modal-close')) this.closeSignature()
    else if (target.closest('.stop-signature-clear')) this.clearSignature()
    else if (target.closest('.stop-signature-save')) this.saveSignature()
  }

  onChange (event) {
    const input = event.target
    if (input.classList.contains('stop-photos-input')) {
      this.uploadPhotos(input)
      return
    }
    if (input.closest('.custom_field, .actual_quantity_field')) {
      const form = input.closest('form')
      if (form) this.submitForm(form)
      const amount = input.closest('.actual_quantity_field')?.querySelector('.quantity-amount')
      if (amount) amount.textContent = input.value
    }
  }

  toggleQuantityEdit (group) {
    if (!group) return
    const editing = group.classList.toggle('is-editing')
    group.querySelectorAll('.quantity-value').forEach((el) => el.classList.toggle('d-none', editing))
    group.querySelectorAll('.quantity-edit').forEach((el) => el.classList.toggle('d-none', !editing))
    const icon = group.querySelector('.actual_quantities-edit i')
    if (icon) icon.className = editing ? 'fa fa-check' : 'fa fa-pencil'
    if (editing) group.querySelector('.quantity-input')?.focus()
  }

  changeStatus (panel, selected, toggleName) {
    const form = panel.querySelector('form.operation-stop-status-form, form.route-status-form') || panel.querySelector('form')
    if (!form) return
    const toggled = toggleName || 'active_status'
    const input = form.querySelector('input[name="stop[status]"], input[name="operation_stop[status]"], input[name="status"]') || form.querySelector(`#${toggled}`)
    if (!input) return
    input.value = selected || ''
    const updated = form.querySelector('input[name="stop[status_updated_at]"], input[name="operation_stop[status_updated_at]"], input[name="status_updated_at"]')
    if (updated) updated.value = new Date().toISOString()

    panel.querySelectorAll(`.radiobtn a[data-toggle="${toggled}"]`).forEach((link) => link.classList.remove('active'))
    if (selected) {
      const match = panel.querySelector(`.radiobtn a[data-toggle="${toggled}"][data-title="${selected}"]`)
      if (match) match.classList.add('active')
    }
    this.swapSuffix(panel.querySelector('#label-index'), 'label-', selected || 'neutral')
    this.swapSuffix(panel.querySelector('.panel-heading'), 'panel-heading-', selected || 'neutral')
    const reset = panel.querySelector('.stop-status-reset')
    if (reset) reset.classList.toggle('d-none', !selected || selected === 'transferred')
    this.updateQuickStatus(panel, selected)
    this.submitForm(form)
  }

  updateQuickStatus (panel, selected) {
    const quick = panel.querySelector('#quick-status')
    const text = panel.querySelector('#quick-status-text')
    if (!quick || !text) return
    const stopType = panel.dataset.stopType
    let next = null
    if (!selected) next = (panel.querySelector('.stop-status-reset') || {}).dataset?.nextStatus || 'intransit'
    else if (stopType === 'visit' && selected === 'intransit') next = 'delivered'
    else if (stopType === 'store' && selected === 'intransit') next = 'atstore'
    else if (stopType === 'store' && selected === 'atstore') next = 'finished'
    else if (stopType === 'rest' && selected === 'started') next = 'finished'
    if (!next) {
      quick.classList.add('d-none')
      return
    }
    quick.classList.remove('d-none')
    quick.dataset.title = next
    const label = panel.querySelector(`.radiobtn a[data-title="${next}"]`)
    text.textContent = label ? label.textContent.trim() : next
  }

  onStatusReset (button) {
    const panel = button.closest('.panel')
    const form = panel?.querySelector('form.operation-stop-status-form, form.route-status-form') || panel?.querySelector('form')
    const input = form?.querySelector('input[name="stop[status]"], input[name="operation_stop[status]"], input[name="status"]')
    if (input?.value === 'transferred') return

    if (!button.classList.contains('confirm-click-armed')) {
      this.element.querySelectorAll('.stop-status-reset.confirm-click-armed').forEach((other) => {
        if (other !== button) this.disarmReset(other)
      })
      this.armReset(button)
      return
    }
    if (button.classList.contains('confirm-click-pending')) return
    this.disarmReset(button)
    if (panel) this.changeStatus(panel, '', button.dataset.toggle)
  }

  closeTransferDropdowns () {
    this.element.querySelectorAll('.route-select.dropdown').forEach((dropdown) => {
      dropdown.classList.remove('show', 'open')
      dropdown.querySelector('.dropdown-menu')?.classList.remove('show')
      dropdown.querySelector('.dropdown-toggle')?.setAttribute('aria-expanded', 'false')
    })
  }

  toggleTransferDropdown (toggle) {
    const dropdown = toggle.closest('.dropdown')
    if (!dropdown) return
    const wasOpen = dropdown.classList.contains('show') || dropdown.classList.contains('open')
    this.closeTransferDropdowns()
    if (wasOpen) return

    const menu = dropdown.querySelector('.dropdown-menu')
    dropdown.classList.add('show', 'open')
    if (menu) menu.classList.add('show')
    toggle.setAttribute('aria-expanded', 'true')
  }

  transferStop (link) {
    const stopId = link.dataset.stopId
    let url = link.dataset.url
    if (!url) return

    const token = new URLSearchParams(window.location.search).get('driver_token')
    if (token) {
      const parsed = new URL(url, window.location.origin)
      parsed.searchParams.set('driver_token', token)
      url = parsed.toString()
    }

    this.closeTransferDropdowns()

    const toggle = link.closest('.route-select')?.querySelector('.dropdown-toggle')
    if (toggle) {
      toggle.disabled = true
      if (!toggle.querySelector('.fa-spinner')) {
        toggle.insertAdjacentHTML('beforeend', ' <i class="fa fa-spinner fa-spin fa-fw" aria-hidden="true"></i>')
      }
    }

    this.patchJson(url, {}).then(() => {
      const panel = this.element.querySelector(`#heading-${stopId}`)?.closest('.panel')
      if (panel) panel.remove()
    }).catch(() => {
      if (!toggle) return
      toggle.disabled = false
      toggle.querySelector('.fa-spinner')?.remove()
    })
  }

  armReset (button) {
    const face = button.querySelector('.stop-status-reset-face') || button
    button.dataset.originalHtml = button.innerHTML
    button.classList.add('confirm-click-armed', 'confirm-click-pending')
    face.classList.add('btn-warning')
    face.classList.remove('btn-default')
    window.setTimeout(() => {
      button.classList.remove('confirm-click-pending')
      if (button.dataset.readyHtml) face.innerHTML = button.dataset.readyHtml
    }, CONFIRM_DELAY)
    window.setTimeout(() => this.disarmReset(button), CONFIRM_DISARM_AFTER)
  }

  disarmReset (button) {
    if (!button.classList.contains('confirm-click-armed')) return
    button.classList.remove('confirm-click-armed', 'confirm-click-pending')
    if (button.dataset.originalHtml) button.innerHTML = button.dataset.originalHtml
  }

  submitForm (form) {
    const url = form.action
    const formData = new FormData(form)
    if (url.includes('/stops/')) formData.append('stop[status_updated_at]', new Date().toISOString())
    const payload = {}
    formData.forEach((value, key) => { payload[key] = value })
    if (!navigator.onLine) {
      this.queueStop(url, payload)
      return
    }
    this.sendForm(url, formData).catch(() => this.queueStop(url, payload))
  }

  queueStop (url, formData) {
    const item = { id: Date.now(), url, formData }
    this.showPending()
    this.postToWorker('STORE_STOP', item)
    this.localSet(`stop_update_${item.id}`, item)
    this.registerSync('sync-stops')
  }

  uploadPhotos (input) {
    if (!input.files.length) return
    const panel = input.closest('.stop-photos')
    const rawFiles = Array.from(input.files)
    const csrf = this.csrfToken()
    const url = panel && panel.dataset.url
    input.value = ''
    if (!url) return
    if (!this.photosWithinLimit(panel, rawFiles.length)) {
      this.showFailed(panel.dataset.tooMany || 'Photos')
      return
    }
    const pendingId = this.queueId()
    // Paint previews first (yield so the UI can render before compression blocks the thread).
    this.showLocalPhotos(panel, rawFiles, pendingId)
    this.afterPaint(() => {
      compressImages(rawFiles).then((files) => {
        this.updatePendingPhotos(panel, pendingId, files)
        const formData = new FormData()
        files.forEach((file) => formData.append('photos[]', file))
        if (csrf) formData.append('authenticity_token', csrf)
        if (!navigator.onLine) {
          this.queuePhoto({ id: pendingId, url, files })
          return
        }
        fetch(url, { method: 'POST', body: formData, headers: { 'X-CSRF-Token': csrf, Accept: 'application/json' } })
          .then(async (response) => {
            if (response.ok) return response.json()
            let data = null
            try { data = await response.json() } catch (_err) { /* ignore */ }
            // Invalid content / client errors: show server messages, never queue for retry.
            if (response.status >= 400 && response.status < 500) {
              this.clearPendingPhotos(panel, pendingId)
              this.showFailed(photoUploadErrorMessage(data, panel.dataset.tooMany || `HTTP ${response.status}`))
              return null
            }
            throw new Error(String(response.status))
          })
          .then((data) => { if (data) this.renderPhotos(panel, data.photos || []) })
          .catch(() => {
            this.queuePhoto({ id: pendingId, url, files })
          })
      })
    })
  }

  afterPaint (fn) {
    window.requestAnimationFrame(() => {
      window.setTimeout(fn, 0)
    })
  }

  photosWithinLimit (panel, incomingCount) {
    const max = Number(panel.dataset.maxCount) || 10
    const list = this.documentsList(panel)
    const current = list
      ? list.querySelectorAll('.stop-photo:not(.stop-photo-pending):not(.stop-signature-doc)').length
      : 0
    return current + incomingCount <= max
  }

  clearPendingPhotos (panel, pendingId) {
    if (!pendingId) return
    const root = panel ? (panel.closest('.stop-documents') || panel) : this.element
    root.querySelectorAll(`.stop-photo-pending[data-pending="${pendingId}"]`).forEach((node) => node.remove())
    if (panel) this.refreshDocuments(panel)
  }

  showLocalPhotos (panel, files, pendingId) {
    const list = this.documentsList(panel)
    if (!list) return
    files.forEach((file) => {
      const url = URL.createObjectURL(file)
      const node = document.createElement('div')
      node.className = 'stop-photo stop-photo-pending'
      if (pendingId) node.dataset.pending = pendingId
      node.innerHTML =
        `<button type="button" class="stop-photo-open" data-url="${url}">` +
          `<img src="${url}" alt="">` +
        `</button>` +
        `<span class="stop-photo-pending-spinner" aria-hidden="true"><i class="fa fa-spinner fa-spin"></i></span>`
      const signature = list.querySelector('.stop-signature-doc')
      if (signature) list.insertBefore(node, signature)
      else list.appendChild(node)
    })
    this.refreshDocuments(panel)
  }

  // Refresh pending thumbs with compressed JPEGs (HEIC often blank until then), before upload.
  updatePendingPhotos (panel, pendingId, files) {
    const list = this.documentsList(panel)
    if (!list || !pendingId) return
    const nodes = Array.from(list.querySelectorAll(`.stop-photo-pending[data-pending="${pendingId}"]`))
    files.forEach((file, index) => {
      const node = nodes[index]
      if (!node) return
      const url = URL.createObjectURL(file)
      const img = node.querySelector('img')
      const open = node.querySelector('.stop-photo-open')
      if (img) {
        const previous = img.getAttribute('src')
        img.src = url
        if (previous && previous.startsWith('blob:')) URL.revokeObjectURL(previous)
      }
      if (open) open.setAttribute('data-url', url)
    })
  }

  documentsList (panel) {
    const root = panel.closest('.stop-documents') || panel
    return root.querySelector('.stop-documents-list')
  }

  deletePhoto (panel, url) {
    panel = resolveStopPhotosPanel(panel)
    if (!url || !panel) return Promise.resolve(false)
    if (!navigator.onLine) {
      this.queuePhoto({ id: this.queueId(), url, method: 'DELETE', panelUrl: panel.dataset.url })
      this.removePhotoNode(panel, url)
      return Promise.resolve(true)
    }
    return fetch(url, { method: 'DELETE', headers: { 'X-CSRF-Token': this.csrfToken(), Accept: 'application/json' } })
      .then((response) => {
        if (response.status === 404) {
          this.removePhotoNode(panel, url)
          return true
        }
        if (!response.ok) throw new Error(String(response.status))
        return response.json().then((data) => {
          if (data.photos) this.renderPhotos(panel, data.photos)
          return true
        })
      })
      .catch(() => {
        this.queuePhoto({ id: this.queueId(), url, method: 'DELETE', panelUrl: panel.dataset.url })
        this.removePhotoNode(panel, url)
        return true
      })
  }

  removePhotoNode (panel, url) {
    const list = this.documentsList(panel)
    const btn = list && Array.from(list.querySelectorAll('.stop-photo-remove'))
      .find((el) => el.getAttribute('data-url') === url)
    if (btn) btn.closest('.stop-photo')?.remove()
    this.refreshDocuments(panel)
  }

  renderPhotos (panel, photos) {
    panel = resolveStopPhotosPanel(panel)
    const list = this.documentsList(panel)
    if (!list || !panel) return
    list.querySelectorAll('.stop-photo:not(.stop-signature-doc)').forEach((node) => node.remove())
    const base = panel.dataset.url
    ;(photos || []).forEach((photo) => {
      const node = document.createElement('div')
      node.className = 'stop-photo'
      const remove = photo.deletable === false ? '' : `<button type="button" class="stop-photo-remove btn btn-xs btn-default" data-url="${base}/${photo.id}"><i class="fa fa-trash"></i></button>`
      node.innerHTML = `${remove}<button type="button" class="stop-photo-open" data-url="${photo.url}"><img src="${photo.url}" alt=""></button>`
      const signature = list.querySelector('.stop-signature-doc')
      if (signature) list.insertBefore(node, signature)
      else list.appendChild(node)
    })
    this.refreshDocuments(panel)
  }

  refreshDocuments (panel) {
    const root = panel.closest('.stop-documents')
    if (!root) return
    const count = root.querySelectorAll('.stop-documents-list .stop-photo').length
    const badge = root.querySelector('.stop-documents-badge')
    if (badge) badge.textContent = String(count)
    root.querySelector('.stop-documents-accordion')?.classList.toggle('d-none', count === 0)
    root.querySelector('.stop-documents-toggle')?.classList.toggle('d-none', count === 0)
    root.querySelector('.stop-documents-body')?.classList.toggle('d-none', count === 0)
    if (count > 0) root.querySelector('.stop-documents-panel')?.classList.remove('d-none')
  }

  queuePhoto (item) {
    this.showPending()
    this.postToWorker('STORE_PHOTO', item)
    this.photoDb().then((db) => {
      const tx = db.transaction(PHOTO_STORE, 'readwrite')
      tx.objectStore(PHOTO_STORE).put(item)
    }).catch(() => {})
    this.registerSync('sync-photos')
  }

  deleteQueuedPhoto (id) {
    if (!id) return Promise.resolve()
    return this.photoDb().then((db) => new Promise((resolve, reject) => {
      const tx = db.transaction(PHOTO_STORE, 'readwrite')
      tx.objectStore(PHOTO_STORE).delete(id)
      tx.oncomplete = () => resolve()
      tx.onerror = () => reject(tx.error)
    })).catch(() => {})
  }

  openPhoto (button) {
    const modal = document.getElementById('stop-photo-modal')
    const list = button.closest('.stop-documents-list')
    this.photoModalPanel = resolveStopPhotosPanel(button)
    this.photoModalItems = this.photoItemsFromList(list, button.dataset.url)
    this.photoModalIndex = Math.max(0, this.photoModalItems.findIndex((item) => item.url === button.dataset.url))
    if (modal) modal.classList.remove('d-none')
    this.showPhoto()
  }

  photoItemsFromList (list, fallbackUrl) {
    if (!list) return fallbackUrl ? [{ url: fallbackUrl, deleteUrl: null }] : []
    return Array.from(list.querySelectorAll('.stop-photo')).map((el) => ({
      url: el.querySelector('.stop-photo-open')?.getAttribute('data-url'),
      deleteUrl: el.querySelector('.stop-photo-remove')?.getAttribute('data-url')
    })).filter((item) => item.url)
  }

  showPhoto () {
    const modal = document.getElementById('stop-photo-modal')
    const item = this.photoModalItems[this.photoModalIndex]
    if (!modal || !item) return
    const img = modal.querySelector('.stop-photo-modal-img')
    if (img) img.src = item.url
    modal.querySelectorAll('.stop-photo-modal-nav').forEach((button) => button.classList.toggle('d-none', this.photoModalItems.length < 2))
    const del = modal.querySelector('.stop-photo-modal-delete')
    if (del) del.classList.toggle('d-none', !item.deleteUrl)
  }

  stepPhoto (delta) {
    if (this.photoModalItems.length < 2) return
    this.photoModalIndex = (this.photoModalIndex + delta + this.photoModalItems.length) % this.photoModalItems.length
    this.showPhoto()
  }

  closePhoto () {
    const modal = document.getElementById('stop-photo-modal')
    if (modal) modal.classList.add('d-none')
    this.photoModalItems = []
  }

  deleteModalPhoto () {
    const item = this.photoModalItems[this.photoModalIndex]
    if (!item?.deleteUrl) return
    const index = this.photoModalIndex
    this.deletePhoto(this.photoModalPanel, item.deleteUrl).then(() => {
      this.syncModalAfterPhotoChange(index)
    })
  }

  syncModalAfterPhotoChange (index) {
    const modal = document.getElementById('stop-photo-modal')
    if (!modal || modal.classList.contains('d-none')) return
    const list = this.documentsList(this.photoModalPanel)
    this.photoModalItems = this.photoItemsFromList(list)
    if (!this.photoModalItems.length) {
      this.closePhoto()
      return
    }
    this.photoModalIndex = nextPhotoModalIndex(index, this.photoModalItems.length)
    this.showPhoto()
  }

  openSignature (panel) {
    this.signaturePanel = panel
    const modal = document.getElementById('stop-signature-modal')
    if (!modal) return
    modal.classList.remove('d-none')
    document.body.style.overflow = 'hidden'
    this.clearSignature()
  }

  closeSignature () {
    const modal = document.getElementById('stop-signature-modal')
    if (!modal) return
    modal.classList.add('d-none')
    document.body.style.overflow = ''
  }

  clearSignature () {
    const canvas = document.querySelector('#stop-signature-modal .stop-signature-canvas')
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    ctx.fillStyle = '#fff'
    ctx.fillRect(0, 0, canvas.width, canvas.height)
    delete canvas.dataset.dirty
  }

  saveSignature () {
    const canvas = document.querySelector('#stop-signature-modal .stop-signature-canvas')
    if (!canvas || !canvas.dataset.dirty || !this.signaturePanel) return
    const url = this.signaturePanel.dataset.url
    canvas.toBlob((blob) => {
      if (!blob || !url) return
      const formData = new FormData()
      formData.append('signature', blob, 'signature.png')
      const csrf = this.csrfToken()
      if (csrf) formData.append('authenticity_token', csrf)
      const preview = canvas.toDataURL('image/png')
      this.renderSignature({ url: preview })
      fetch(url, { method: 'POST', body: formData, headers: { 'X-CSRF-Token': csrf, Accept: 'application/json' } })
        .then((response) => {
          if (!response.ok) throw new Error(String(response.status))
          return response.json()
        })
        .then((data) => {
          if (data.signature) this.renderSignature(data.signature)
          this.closeSignature()
        })
    }, 'image/png')
  }

  renderSignature (signature) {
    const list = this.signaturePanel.closest('.stop-documents')?.querySelector('.stop-documents-list')
    if (!list) return
    list.querySelectorAll('.stop-signature-doc').forEach((node) => node.remove())
    const node = document.createElement('div')
    node.className = 'stop-photo stop-signature-doc'
    node.innerHTML = `<button type="button" class="stop-photo-open" data-url="${signature.url}"><img src="${signature.url}" alt=""></button>`
    list.appendChild(node)
    this.refreshDocuments(this.signaturePanel)
  }

  bindSignatureCanvas () {
    const canvas = document.querySelector('#stop-signature-modal .stop-signature-canvas')
    if (!canvas || canvas.dataset.bound) return
    canvas.dataset.bound = '1'
    const ctx = canvas.getContext('2d')
    let drawing = false
    const pos = (event) => {
      const rect = canvas.getBoundingClientRect()
      const src = event.touches ? event.touches[0] : event
      return {
        x: (src.clientX - rect.left) * (canvas.width / rect.width),
        y: (src.clientY - rect.top) * (canvas.height / rect.height)
      }
    }
    const start = (event) => {
      drawing = true
      const point = pos(event)
      ctx.beginPath()
      ctx.moveTo(point.x, point.y)
    }
    const move = (event) => {
      if (!drawing) return
      event.preventDefault()
      const point = pos(event)
      ctx.lineWidth = 3
      ctx.lineCap = 'round'
      ctx.strokeStyle = '#111'
      ctx.lineTo(point.x, point.y)
      ctx.stroke()
      canvas.dataset.dirty = '1'
    }
    canvas.addEventListener('mousedown', start)
    canvas.addEventListener('mousemove', move)
    canvas.addEventListener('mouseup', () => { drawing = false })
    canvas.addEventListener('mouseleave', () => { drawing = false })
    canvas.addEventListener('touchstart', start, { passive: true })
    canvas.addEventListener('touchmove', move, { passive: false })
    canvas.addEventListener('touchend', () => { drawing = false })
  }

  openNavigation (link) {
    const primary = link.dataset.navPrimary
    const fallback = link.getAttribute('href')
    const started = Date.now()
    const timer = window.setTimeout(() => {
      if (!document.hidden && Date.now() - started < 1700) window.location.href = fallback
    }, 1200)
    document.addEventListener('visibilitychange', function hide () {
      if (!document.hidden) return
      window.clearTimeout(timer)
      document.removeEventListener('visibilitychange', hide)
    })
    window.location.href = primary
  }

  swapSuffix (node, prefix, value) {
    if (!node) return
    Array.from(node.classList).forEach((name) => {
      if (name.startsWith(prefix)) node.classList.remove(name)
    })
    if (value) node.classList.add(prefix + value)
  }

  registerServiceWorker () {
    if (!('serviceWorker' in navigator)) return
    const token = this.csrfToken()
    navigator.serviceWorker.addEventListener('message', this.onServiceMessage)
    navigator.serviceWorker.register('/service-worker.js', { scope: '/' }).then((registration) => {
      registration.active?.postMessage({ type: 'SET_CSRF_TOKEN', token })
    }).catch(() => {})
  }

  onServiceMessage (event) {
    const type = event.data && event.data.type
    const payload = event.data && event.data.data
    if (type === 'POSITION_SYNCED' || type === 'POSITION_DROPPED') {
      this.clearQueuedPosition(payload && payload.id)
      this.hidePending()
    }
    if (type === 'STOP_SYNCED' || type === 'ROUTE_SYNCED') {
      this.hidePending()
    }
    if (type === 'PHOTO_SYNCED') {
      this.deleteQueuedPhoto(payload && payload.id)
      if (payload && payload.photos) {
        const panel = this.findPhotoPanel(payload.panelUrl || payload.url)
        if (panel) this.renderPhotos(panel, payload.photos)
      }
      this.hidePending()
    }
    if (type === 'PHOTO_REJECTED') {
      this.deleteQueuedPhoto(payload && payload.id)
      if (payload && payload.id) this.clearPendingPhotos(this.findPhotoPanel(payload.panelUrl || payload.url), payload.id)
      this.showFailed(photoUploadErrorMessage(payload, 'Photos'))
    }
    if (type === 'SYNC_ERROR') this.showFailed()
    if (type === 'GET_PENDING_DATA') {
      event.source.postMessage({ type: 'PENDING_DATA', data: this.pendingPayload() })
    }
  }

  findPhotoPanel (url) {
    if (!url) return null
    return Array.from(this.element.querySelectorAll('.stop-photos')).find((panel) => panel.dataset.url === url) || null
  }

  onOnline () {
    this.flushPending()
  }

  flushPending () {
    if (!navigator.onLine) return
    this.registerSync('sync-positions')
    this.registerSync('sync-stops')
    this.registerSync('sync-photos')
    Object.keys(localStorage).forEach((key) => {
      const item = this.readStored(key)
      if (!item) return
      const request = key.startsWith('position_')
        ? this.patchJson(item.url, item.coords)
        : this.sendStoredForm(item)
      request
        .then(() => localStorage.removeItem(key))
        .then(() => this.hidePending())
        .catch((error) => {
          // Drop dead GPS URLs from the queue; keep stops/routes for retry.
          if (key.startsWith('position_') && this.isGoneError(error)) {
            localStorage.removeItem(key)
            this.hidePending()
          }
        })
    })
  }

  pendingPayload () {
    const data = { positions: [], stops: [], routes: [], photos: [] }
    Object.keys(localStorage).forEach((key) => {
      const item = this.readStored(key)
      if (!item) return
      if (key.startsWith('position_')) data.positions.push(item)
      else if (key.startsWith('stop_update_')) data.stops.push(item)
      else if (key.startsWith('route_update_')) data.routes.push(item)
    })
    return data
  }

  readStored (key) {
    if (!key.startsWith('position_') && !key.startsWith('stop_update_') && !key.startsWith('route_update_')) return null
    try {
      return JSON.parse(localStorage.getItem(key))
    } catch (error) {
      return null
    }
  }

  patchJson (url, body) {
    return fetch(url, {
      method: 'PATCH',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'X-CSRF-Token': this.csrfToken(),
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify(body)
    }).then((response) => {
      if (!response.ok) throw new Error(String(response.status))
    })
  }

  // Permanent failures: do not keep retrying GPS to a missing operation route.
  isGoneError (error) {
    const status = String(error && error.message)
    return status === '404' || status === '409'
  }

  sendForm (url, formData) {
    return fetch(url, {
      method: 'PATCH',
      body: formData,
      headers: { 'X-CSRF-Token': this.csrfToken(), Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest' }
    }).then((response) => {
      if (!response.ok) throw new Error(String(response.status))
    })
  }

  sendStoredForm (item) {
    const formData = new FormData()
    Object.keys(item.formData || {}).forEach((key) => formData.append(key, item.formData[key]))
    return this.sendForm(item.url, formData)
  }

  postToWorker (type, payload) {
    if (!('serviceWorker' in navigator) || !navigator.serviceWorker.controller) return
    navigator.serviceWorker.controller.postMessage({ type, payload })
  }

  registerSync (tag) {
    if (!('serviceWorker' in navigator) || !('SyncManager' in window)) return
    navigator.serviceWorker.ready.then((registration) => registration.sync.register(tag)).catch(() => {})
  }

  photoDb () {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(PHOTO_DB, 1)
      request.onupgradeneeded = () => {
        if (!request.result.objectStoreNames.contains(PHOTO_STORE)) {
          request.result.createObjectStore(PHOTO_STORE, { keyPath: 'id' })
        }
      }
      request.onsuccess = () => resolve(request.result)
      request.onerror = () => reject(request.error)
    })
  }

  showPending () {
    document.getElementById('mobile-sync-pending')?.classList.remove('d-none')
  }

  hidePending () {
    document.getElementById('mobile-sync-pending')?.classList.add('d-none')
  }

  showFailed (message) {
    const node = document.getElementById('mobile-sync-failed')
    if (!node) return
    const span = node.querySelector('span')
    if (span) {
      if (!span.dataset.defaultText) span.dataset.defaultText = span.textContent
      span.textContent = message || span.dataset.defaultText
      span.style.whiteSpace = message && String(message).includes('\n') ? 'pre-line' : ''
    }
    this.hidePending()
    node.classList.remove('d-none')
    window.clearTimeout(this._failedTimer)
    this._failedTimer = window.setTimeout(() => {
      node.classList.add('d-none')
      if (span && span.dataset.defaultText) {
        span.textContent = span.dataset.defaultText
        span.style.whiteSpace = ''
      }
    }, message ? 5000 : 3000)
  }

  localSet (key, value) {
    localStorage.setItem(key, JSON.stringify(value))
  }

  queueId () {
    return `${Date.now()}-${Math.random().toString(36).slice(2)}`
  }

  csrfToken () {
    return document.querySelector('meta[name="csrf-token"]')?.content || ''
  }

  // Reject NaN/±Infinity and WebView sentinels like ±Number.MAX_VALUE.
  saneSensor (value, min, max) {
    return Number.isFinite(value) && value >= min && value <= max
  }
}
