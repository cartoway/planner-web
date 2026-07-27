// Copyright © Cartoway
// Geocode button in v2 sidebar form: visible when address fields are filled, runs geocode on demand.
import { Controller } from '@hotwired/stimulus'

const ADDRESS_FIELDS = ['street', 'postalcode', 'city', 'state', 'country']

const SKIP_GEOCODE_REQUEST_NAMES = new Set([
  'destination[geocode_on_save]',
  'destination[geocode_on_save_fingerprint]'
])

export default class extends Controller {
  static targets = [
    'prompt',
    'geocodeButton',
    'geocodeButtonLabel',
    'geocodingResultRow',
    'geocodeApplyPanel',
    'geocodeApplyButton'
  ]

  static values = {
    geocodeUrl: { type: String, default: '/api/0.1/destinations/geocode.json' },
    confirmOverwritePoint: String,
    geocodeInProgress: String,
    accuracySuccess: Number,
    accuracyWarning: Number,
    geocodingLevelLabels: Object
  }

  connect () {
    this._addressInputs = ADDRESS_FIELDS
      .map((field) => this._input(field))
      .filter(Boolean)
    if (!this._addressInputs.length) return

    this._pendingGeocodedAddress = null
    this._geocodedAddressFingerprint = null
    this._onAddressBlur = this._onAddressBlur.bind(this)
    this._onAddressInput = this._onAddressInput.bind(this)
    this._addressInputs.forEach((input) => {
      input.addEventListener('blur', this._onAddressBlur)
      input.addEventListener('input', this._onAddressInput)
    })
    this._syncPromptVisibility()
    this._syncGeocodeApplyPanelFromStoredResult()
  }

  disconnect () {
    this._addressInputs?.forEach((input) => {
      input.removeEventListener('blur', this._onAddressBlur)
      input.removeEventListener('input', this._onAddressInput)
    })
  }

  _input (field) {
    const name = field.startsWith('destination[') ? field : `destination[${field}]`
    return this.element.querySelector(`input[name="${name}"]`)
  }

  _readAddressFields () {
    return Object.fromEntries(
      ADDRESS_FIELDS.map((field) => [field, this._input(field)?.value ?? ''])
    )
  }

  _normalizeAddressValue (value) {
    return String(value ?? '').trim().replace(/\s+/g, ' ').toLowerCase()
  }

  _addressFingerprint (fields = null) {
    const f = fields || this._readAddressFields()
    return ADDRESS_FIELDS.map((field) => this._normalizeAddressValue(f[field])).join('|')
  }

  _addressFieldsDiffer (enteredAddress, geocodedAddress) {
    if (!geocodedAddress) return false
    return ADDRESS_FIELDS.some((field) =>
      this._normalizeAddressValue(enteredAddress[field]) !==
      this._normalizeAddressValue(geocodedAddress[field])
    )
  }

  _readStoredGeocodingResult () {
    const raw = this._input('geocoding_result')?.value
    if (!raw) return null
    try {
      return JSON.parse(raw)
    } catch (e) {
      return null
    }
  }

  _geocodedAddressFromResult (result) {
    if (!result) return null
    const free = result.free ?? result.label
    if (!free) return null

    let street = result.street || ''
    if (result.housenumber) {
      street = `${result.housenumber}${street ? ` ${street}` : ''}`.trim()
    } else if (!street && result.name) {
      street = result.name
    }

    return {
      street,
      postalcode: result.postcode || result.postalcode || '',
      city: result.city || '',
      state: result.state || '',
      country: result.country || ''
    }
  }

  _syncGeocodeApplyPanelFromStoredResult (enteredAddress = null) {
    const geocodedAddress = this._geocodedAddressFromResult(this._readStoredGeocodingResult())
    if (!geocodedAddress) {
      this._pendingGeocodedAddress = null
      this._toggleTarget('geocodeApplyPanel', false)
      return
    }

    const entered = enteredAddress || this._readAddressFields()
    if (this._addressFieldsDiffer(entered, geocodedAddress)) {
      this._pendingGeocodedAddress = geocodedAddress
      this._toggleTarget('geocodeApplyPanel', true)
    } else {
      this._pendingGeocodedAddress = null
      this._toggleTarget('geocodeApplyPanel', false)
    }
  }

  _setGeocodeOnSavePending () {
    const fingerprint = this._addressFingerprint()
    this._geocodedAddressFingerprint = fingerprint
    this._setInputValue('geocode_on_save', '1', { silent: true })
    this._setInputValue('geocode_on_save_fingerprint', fingerprint, { silent: true })
  }

  _invalidatePendingGeocode () {
    this._geocodedAddressFingerprint = null
    this._pendingGeocodedAddress = null
    this._setInputValue('geocode_on_save', '', { silent: true })
    this._setInputValue('geocode_on_save_fingerprint', '', { silent: true })
    this._clearTemporaryGeocodePreview()
    this._toggleTarget('geocodeApplyPanel', false)
  }

  _clearTemporaryGeocodePreview () {
    const geocodingResultInput = this._input('geocoding_result')
    if (geocodingResultInput) geocodingResultInput.value = '{}'

    const displayedResult = this.element.querySelector('#displayed-geocoding-result')
    if (displayedResult) displayedResult.value = ''

    this._toggleTarget('geocodingResultRow', false)
    this._setInputValue('geocoder_version', '', { silent: true })
    this._setInputValue('geocoded_at', '', { silent: true })
    this._displayGeocodingNotApplicable()
  }

  _hasAddress () {
    return ADDRESS_FIELDS.some((field) => this._input(field)?.value.trim() !== '')
  }

  _syncPromptVisibility () {
    this._toggleTarget('prompt', this._hasAddress())
  }

  _onAddressInput () {
    if (this._geocodingInFlight) return
    this._syncPromptVisibility()
    if (this._geocodedAddressFingerprint != null &&
        this._addressFingerprint() !== this._geocodedAddressFingerprint) {
      this._invalidatePendingGeocode()
    }
  }

  _onAddressBlur () {
    if (this._geocodingInFlight) return
    this._syncGeocodeApplyPanelFromStoredResult()
  }

  _toggleTarget (targetName, visible) {
    const hasTargetKey = `has${targetName.charAt(0).toUpperCase()}${targetName.slice(1)}Target`
    const targetKey = `${targetName}Target`
    if (!this[hasTargetKey]) return
    this[targetKey].classList.toggle('d-none', !visible)
  }

  async geocode (event) {
    event.preventDefault()
    if (this._geocodingInFlight) return

    if (this._input('geocoding_level')?.value === 'point') {
      const message = this.confirmOverwritePointValue
      if (message && !window.confirm(message)) return
    }

    const addressBeforeGeocode = this._readAddressFields()
    this._toggleTarget('geocodeApplyPanel', false)
    this._pendingGeocodedAddress = null
    this._clearLatLng()
    this._setGeocodingBusy(true)

    try {
      const destination = await this._fetchGeocode()
      this._applyGeocodeResult(destination)
      this._setGeocodeOnSavePending()
      this._syncGeocodeApplyPanelFromStoredResult(addressBeforeGeocode)
      this._syncPromptVisibility()
      this._dispatchGeocodedEvent(destination)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('destination geocoding failed', e)
      this._toggleTarget('geocodeApplyPanel', false)
      this._pendingGeocodedAddress = null
    } finally {
      this._setGeocodingBusy(false)
    }
  }

  applyGeocodedAddress (event) {
    event.preventDefault()
    const destination = this._pendingGeocodedAddress
    if (!destination) return

    ADDRESS_FIELDS.forEach((field) => {
      if (destination[field] === undefined) return
      this._setInputValue(field, destination[field])
    })

    this._setGeocodeOnSavePending()
    this._toggleTarget('geocodeApplyPanel', false)
    this._syncPromptVisibility()
  }

  _clearLatLng () {
    const latInput = this.element.querySelector('#destination_lat, input[name="destination[lat]"]')
    const lngInput = this.element.querySelector('#destination_lng, input[name="destination[lng]"]')
    if (latInput) latInput.value = ''
    if (lngInput) lngInput.value = ''
  }

  _setGeocodingBusy (busy) {
    this._geocodingInFlight = busy
    if (!this.hasGeocodeButtonTarget) return
    this.geocodeButtonTarget.disabled = busy
    if (this.hasGeocodeApplyButtonTarget) this.geocodeApplyButtonTarget.disabled = busy
    if (this.hasGeocodeButtonLabelTarget && this.geocodeInProgressValue) {
      if (busy) {
        if (this._geocodeButtonDefaultLabel == null) {
          this._geocodeButtonDefaultLabel = this.geocodeButtonLabelTarget.textContent
        }
        this.geocodeButtonLabelTarget.textContent = this.geocodeInProgressValue
      } else if (this._geocodeButtonDefaultLabel != null) {
        this.geocodeButtonLabelTarget.textContent = this._geocodeButtonDefaultLabel
      }
    }
  }

  async _fetchGeocode () {
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    const params = new URLSearchParams()
    this.element.querySelectorAll('input[name^="destination["]').forEach((input) => {
      if (input.type === 'checkbox' || input.type === 'radio') return
      if (SKIP_GEOCODE_REQUEST_NAMES.has(input.name)) return
      params.append(input.name, input.value)
    })

    const response = await fetch(this.geocodeUrlValue, {
      method: 'PATCH',
      headers: {
        Accept: 'application/json',
        'X-CSRF-Token': token || '',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: params.toString(),
      credentials: 'same-origin'
    })

    if (!response.ok) throw new Error(`geocode HTTP ${response.status}`)
    return response.json()
  }

  _applyGeocodeResult (destination) {
    this._setInputValue('lat', destination.lat)
    this._setInputValue('lng', destination.lng)
    this._setInputValue('geocoder_version', destination.geocoder_version)
    this._setInputValue('geocoded_at', destination.geocoded_at)

    const reverseGeocode = this.element.querySelector('#reverse-geocode')
    if (reverseGeocode) reverseGeocode.innerHTML = ''

    const payload = this._geocodingResultPayload(destination)
    const geocodingResultInput = this._input('geocoding_result')
    if (geocodingResultInput) {
      geocodingResultInput.value = payload ? JSON.stringify(payload) : '{}'
    }

    const displayedResult = this.element.querySelector('#displayed-geocoding-result')
    const resultFree = payload?.free || null
    if (displayedResult) displayedResult.value = resultFree || ''

    this._toggleTarget('geocodingResultRow', Boolean(resultFree))

    if (destination.street || destination.postalcode || destination.city) {
      if (destination.geocoding_accuracy) this._displayGeocodingAccuracy(destination)
      else this._displayGeocodingFailure()
    } else {
      this._displayGeocodingNotApplicable()
    }
  }

  // Persist the full geocoder payload; always expose address label under `free`.
  _geocodingResultPayload (destination) {
    const raw = destination?.geocoding_result
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null

    const free = raw.free || raw.label || null
    if (!free) return { ...raw }

    return { ...raw, free }
  }

  _setInputValue (field, value, { silent = false } = {}) {
    const input = this._input(field)
    if (!input || value === undefined) return
    input.value = value == null ? '' : value
    if (silent) return
    input.dispatchEvent(new Event('input', { bubbles: true }))
    input.dispatchEvent(new Event('change', { bubbles: true }))
  }

  _displayGeocodingAccuracy (destination) {
    const accuracy = destination.geocoding_accuracy
    const percent = Math.round(accuracy * 100)
    let status = 'danger'
    if (accuracy > this.accuracySuccessValue) status = 'success'
    else if (accuracy > this.accuracyWarningValue) status = 'warning'

    this._setGeocodingBlocksVisible({ accuracy: true, fail: false, none: false, level: true })

    const progressBar = this.element.querySelector('#geocoding-progress .progress-bar')
    if (progressBar) {
      progressBar.style.width = `${percent}%`
      progressBar.classList.remove('progress-bar-success', 'progress-bar-warning', 'progress-bar-danger')
      progressBar.classList.add(`progress-bar-${status}`)
      const span = progressBar.querySelector('span')
      if (span) span.textContent = `${percent}%`
    }

    this._setInputValue('geocoding_accuracy', accuracy)
    this._displayGeocodingLevel(destination.geocoding_level)
  }

  _displayGeocodingFailure () {
    this._setGeocodingBlocksVisible({ accuracy: false, fail: true, none: false, level: false })
    this._setInputValue('geocoding_accuracy', '')
    this._setInputValue('geocoding_level', '')
  }

  _displayGeocodingNotApplicable () {
    this._setGeocodingBlocksVisible({ accuracy: false, fail: false, none: true, level: false })
    this._setInputValue('geocoding_accuracy', '')
    this._setInputValue('geocoding_level', '')
  }

  _setGeocodingBlocksVisible ({ accuracy, fail, none, level }) {
    this.element.querySelector('#geocoding_accuracy')?.classList.toggle('d-none', !accuracy)
    this.element.querySelector('#geocoding_fail')?.classList.toggle('d-none', !fail)
    this.element.querySelector('#no_geocoding_accuracy')?.classList.toggle('d-none', !none)
    this.element.querySelector('#geocoding_level')?.classList.toggle('d-none', !level)
  }

  _displayGeocodingLevel (level) {
    const levelBlock = this.element.querySelector('#geocoding_level')
    const noneBlock = this.element.querySelector('#no_geocoding_accuracy')
    levelBlock?.classList.remove('d-none')
    noneBlock?.classList.toggle('d-none', level !== 'point')

    this._setInputValue('geocoding_level', level || '')

    this.element.querySelectorAll('[data-geocoding-level]').forEach((icon) => {
      icon.classList.toggle('d-none', icon.getAttribute('data-geocoding-level') !== level)
    })

    const levelValue = this.element.querySelector('#geocoding-level-value')
    if (levelValue && level) {
      levelValue.textContent = this.geocodingLevelLabelsValue[level] || level
    }
  }

  _dispatchGeocodedEvent (destination) {
    const form = this.element.closest('#destination-form-sidebar')
    const destinationId = form?.getAttribute('data-destination_id') || '0'
    this.element.dispatchEvent(new CustomEvent('v2:destination-geocoded', {
      bubbles: true,
      detail: {
        destinationId: String(destinationId),
        lat: destination.lat,
        lng: destination.lng,
        name: destination.name || ''
      }
    }))
  }
}
