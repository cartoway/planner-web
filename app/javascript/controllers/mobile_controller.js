import { Controller } from '@hotwired/stimulus'

const CONFIRM_DELAY = 200
const CONFIRM_DISARM_AFTER = 4000
const PHOTO_DB = 'planner-mobile-photos'
const PHOTO_STORE = 'pending'

// Driver route screen: status, photos, signature and GPS.
// Offline writes stay in localStorage / IndexedDB and flush through the service worker.
export default class extends Controller {
  static values = { positionUrl: String }

  connect () {
    this.positionTimer = null
    this.photoModalItems = []
    this.photoModalIndex = 0
    this.photoModalPanel = null
    this.signaturePanel = null
    this.onClick = this.onClick.bind(this)
    this.onChange = this.onChange.bind(this)
    this.onOnline = this.onOnline.bind(this)
    this.onServiceMessage = this.onServiceMessage.bind(this)
    this.element.addEventListener('click', this.onClick)
    this.element.addEventListener('change', this.onChange)
    window.addEventListener('online', this.onOnline)
    this.bindSignatureCanvas()
    this.registerServiceWorker()
    if (sessionStorage.getItem('tracking_value') !== 'false') this.startTracking()
    this.flushPending()
  }

  disconnect () {
    this.stopTracking()
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
      const body = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        accuracy: position.coords.accuracy,
        altitude: position.coords.altitude,
        heading: position.coords.heading,
        speed: position.coords.speed,
        positioned_at: new Date().toISOString()
      }
      if (!navigator.onLine) {
        this.queuePosition(body)
        return
      }
      this.patchJson(this.positionUrlValue, body).catch(() => this.queuePosition(body))
    })
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
      if (panel) {
        event.preventDefault()
        panel.classList.toggle('in')
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
      this.deletePhoto(button.closest('.stop-photos') || button.closest('.stop-documents'), button.dataset.url)
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
    this.swapSuffix(panel.querySelector('#label-index'), 'label-', selected)
    this.swapSuffix(panel.querySelector('.panel-heading'), 'panel-heading-', selected)
    const reset = panel.querySelector('.stop-status-reset')
    if (reset) reset.classList.toggle('d-none', !selected)
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
    if (!button.classList.contains('confirm-click-armed')) {
      this.element.querySelectorAll('.stop-status-reset.confirm-click-armed').forEach((other) => {
        if (other !== button) this.disarmReset(other)
      })
      this.armReset(button)
      return
    }
    if (button.classList.contains('confirm-click-pending')) return
    this.disarmReset(button)
    const panel = button.closest('.panel')
    if (panel) this.changeStatus(panel, '', button.dataset.toggle)
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
    const files = Array.from(input.files)
    const formData = new FormData()
    files.forEach((file) => formData.append('photos[]', file))
    const csrf = this.csrfToken()
    if (csrf) formData.append('authenticity_token', csrf)
    const url = panel && panel.dataset.url
    input.value = ''
    if (!url) return
    this.showLocalPhotos(panel, files)
    if (!navigator.onLine) {
      this.queuePhoto({ id: this.queueId(), url, files })
      return
    }
    fetch(url, { method: 'POST', body: formData, headers: { 'X-CSRF-Token': csrf, Accept: 'application/json' } })
      .then((response) => {
        if (!response.ok) throw new Error(String(response.status))
        return response.json()
      })
      .then((data) => this.renderPhotos(panel, data.photos || []))
      .catch(() => this.queuePhoto({ id: this.queueId(), url, files }))
  }

  showLocalPhotos (panel, files) {
    const list = this.documentsList(panel)
    if (!list) return
    files.forEach((file) => {
      const url = URL.createObjectURL(file)
      const node = document.createElement('div')
      node.className = 'stop-photo stop-photo-pending'
      node.innerHTML = `<button type="button" class="stop-photo-open" data-url="${url}"><img src="${url}" alt=""></button>`
      list.appendChild(node)
    })
    this.refreshDocuments(panel)
  }

  documentsList (panel) {
    const root = panel.closest('.stop-documents') || panel
    return root.querySelector('.stop-documents-list')
  }

  deletePhoto (panel, url) {
    if (!url) return
    if (!navigator.onLine) {
      this.queuePhoto({ id: this.queueId(), url, method: 'DELETE', panelUrl: panel && panel.dataset.url })
      return
    }
    fetch(url, { method: 'DELETE', headers: { 'X-CSRF-Token': this.csrfToken(), Accept: 'application/json' } })
      .then((response) => response.json())
      .then((data) => { if (panel && data.photos) this.renderPhotos(panel, data.photos) })
      .catch(() => this.queuePhoto({ id: this.queueId(), url, method: 'DELETE' }))
  }

  renderPhotos (panel, photos) {
    const list = this.documentsList(panel)
    if (!list) return
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

  openPhoto (button) {
    const modal = document.getElementById('stop-photo-modal')
    const list = button.closest('.stop-documents-list')
    this.photoModalPanel = button.closest('.stop-photos')
    this.photoModalItems = list ? Array.from(list.querySelectorAll('.stop-photo')).map((el) => ({
      url: el.querySelector('.stop-photo-open')?.getAttribute('data-url'),
      deleteUrl: el.querySelector('.stop-photo-remove')?.getAttribute('data-url')
    })).filter((item) => item.url) : [{ url: button.dataset.url, deleteUrl: null }]
    this.photoModalIndex = Math.max(0, this.photoModalItems.findIndex((item) => item.url === button.dataset.url))
    if (modal) modal.classList.remove('d-none')
    this.showPhoto()
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
    if (item && item.deleteUrl) this.deletePhoto(this.photoModalPanel, item.deleteUrl)
    this.closePhoto()
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
    if (type === 'POSITION_SYNCED' || type === 'STOP_SYNCED' || type === 'PHOTO_SYNCED' || type === 'ROUTE_SYNCED') {
      this.hidePending()
    }
    if (type === 'SYNC_ERROR') this.showFailed()
    if (type === 'GET_PENDING_DATA') {
      event.source.postMessage({ type: 'PENDING_DATA', data: this.pendingPayload() })
    }
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
      request.then(() => localStorage.removeItem(key)).then(() => this.hidePending()).catch(() => {})
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
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'X-CSRF-Token': this.csrfToken()
      },
      body: JSON.stringify(body)
    }).then((response) => {
      if (!response.ok) throw new Error(String(response.status))
    })
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

  showFailed () {
    const node = document.getElementById('mobile-sync-failed')
    if (!node) return
    node.classList.remove('d-none')
    window.setTimeout(() => node.classList.add('d-none'), 3000)
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
}
