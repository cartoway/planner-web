// Copyright © Cartoway
// Suggest geocoding after address fields change (blur), via a non-blocking button (v2 sidebar form).
import { Controller } from '@hotwired/stimulus'

const ADDRESS_FIELD_NAMES = new Set([
  'destination[street]',
  'destination[postalcode]',
  'destination[city]',
  'destination[state]',
  'destination[country]'
])

const ADDRESS_FIELDS = ['street', 'postalcode', 'city', 'state', 'country']

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
    this._addressInputs = this._findAddressInputs()
    if (!this._addressInputs.length) return

    this._snapshot = this._addressSnapshot()
    this._pendingGeocodedAddress = null
    this._onAddressBlur = this._onAddressBlur.bind(this)
    this._addressInputs.forEach((input) => {
      input.addEventListener('blur', this._onAddressBlur)
    })
    this._hidePrompt()
    this._syncGeocodeApplyPanelFromStoredResult()
  }

  disconnect () {
    if (!this._addressInputs) return
    this._addressInputs.forEach((input) => {
      input.removeEventListener('blur', this._onAddressBlur)
    })
  }

  _findAddressInputs () {
    return Array.from(this.element.querySelectorAll('input[name]')).filter((input) =>
      ADDRESS_FIELD_NAMES.has(input.name)
    )
  }

  _addressSnapshot () {
    const snapshot = {}
    this._addressInputs.forEach((input) => {
      snapshot[input.name] = input.value
    })
    return snapshot
  }

  _readAddressFields () {
    const fields = {}
    ADDRESS_FIELDS.forEach((field) => {
      const input = this.element.querySelector(`input[name="destination[${field}]"]`)
      if (input) fields[field] = input.value
    })
    return fields
  }

  _normalizeAddressValue (value) {
    return String(value ?? '').trim().replace(/\s+/g, ' ').toLowerCase()
  }

  _addressFieldsDiffer (enteredAddress, geocodedDestination) {
    if (!geocodedDestination) return false
    return ADDRESS_FIELDS.some((field) => {
      const input = this.element.querySelector(`input[name="destination[${field}]"]`)
      if (!input) return false
      const entered = this._normalizeAddressValue(enteredAddress[field])
      const geocoded = this._normalizeAddressValue(geocodedDestination[field])
      return entered !== geocoded
    })
  }

  _readStoredGeocodingResult () {
    const input = this.element.querySelector('input[name="destination[geocoding_result]"]')
    if (!input?.value) return null
    try {
      return JSON.parse(input.value)
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
      this._hideGeocodeApplyPanel()
      return
    }

    const entered = enteredAddress || this._readAddressFields()
    if (this._addressFieldsDiffer(entered, geocodedAddress)) {
      this._pendingGeocodedAddress = geocodedAddress
      this._showGeocodeApplyPanel()
    } else {
      this._pendingGeocodedAddress = null
      this._hideGeocodeApplyPanel()
    }
  }

  _addressChanged () {
    return this._addressInputs.some((input) => input.value !== this._snapshot[input.name])
  }

  _onAddressBlur () {
    if (this._geocodingInFlight) return
    if (this._addressChanged()) this._showPrompt()
    else this._hidePrompt()
    this._syncGeocodeApplyPanelFromStoredResult()
  }

  _showPrompt () {
    if (!this.hasPromptTarget) return
    this.promptTarget.classList.remove('d-none')
  }

  _hidePrompt () {
    if (!this.hasPromptTarget) return
    this.promptTarget.classList.add('d-none')
  }

  _showGeocodeApplyPanel () {
    if (!this.hasGeocodeApplyPanelTarget) return
    this.geocodeApplyPanelTarget.classList.remove('d-none')
  }

  _hideGeocodeApplyPanel () {
    if (!this.hasGeocodeApplyPanelTarget) return
    this.geocodeApplyPanelTarget.classList.add('d-none')
  }

  async geocode (event) {
    event.preventDefault()
    if (this._geocodingInFlight) return

    const geocodingLevelInput = this.element.querySelector('input[name="destination[geocoding_level]"]')
    if (geocodingLevelInput?.value === 'point') {
      const message = this.confirmOverwritePointValue
      if (message && !window.confirm(message)) return
    }

    const addressBeforeGeocode = this._readAddressFields()
    this._hideGeocodeApplyPanel()
    this._pendingGeocodedAddress = null
    this._clearLatLng()
    this._setGeocodingBusy(true)

    try {
      const destination = await this._fetchGeocode()
      this._applyGeocodeResult(destination)
      this._syncGeocodeApplyPanelFromStoredResult(addressBeforeGeocode)
      this._snapshot = this._addressSnapshot()
      this._hidePrompt()
      this._dispatchGeocodedEvent(destination)
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('destination geocoding failed', e)
      this._hideGeocodeApplyPanel()
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
      const input = this.element.querySelector(`input[name="destination[${field}]"]`)
      if (!input || destination[field] === undefined) return
      this._setInputValue(`destination[${field}]`, destination[field])
    })

    this._snapshot = this._addressSnapshot()
    this._hideGeocodeApplyPanel()
    this._hidePrompt()
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
    this._setInputValue('destination[lat]', destination.lat)
    this._setInputValue('destination[lng]', destination.lng)
    this._setInputValue('destination[geocoder_version]', destination.geocoder_version)
    this._setInputValue('destination[geocoded_at]', destination.geocoded_at)

    const reverseGeocode = this.element.querySelector('#reverse-geocode')
    if (reverseGeocode) reverseGeocode.innerHTML = ''

    const geocodingResultInput = this.element.querySelector('input[name="destination[geocoding_result]"]')
    if (geocodingResultInput && destination.geocoding_result) {
      geocodingResultInput.value = JSON.stringify(destination.geocoding_result)
    }

    const displayedResult = this.element.querySelector('#displayed-geocoding-result')
    const resultFree = destination.geocoding_result?.free ?? destination.geocoding_result?.label
    if (displayedResult && resultFree) displayedResult.value = resultFree

    if (this.hasGeocodingResultRowTarget) {
      if (resultFree) this.geocodingResultRowTarget.classList.remove('d-none')
      else this.geocodingResultRowTarget.classList.add('d-none')
    }

    if (destination.street || destination.postalcode || destination.city) {
      if (destination.geocoding_accuracy) {
        this._displayGeocodingAccuracy(destination)
      } else {
        this._displayGeocodingFailure()
      }
    } else {
      this._displayGeocodingNotApplicable()
    }
  }

  _setInputValue (name, value) {
    const input = this.element.querySelector(`input[name="${name}"]`)
    if (!input || value === undefined) return
    input.value = value == null ? '' : value
    input.dispatchEvent(new Event('input', { bubbles: true }))
    input.dispatchEvent(new Event('change', { bubbles: true }))
  }

  _displayGeocodingAccuracy (destination) {
    const accuracy = destination.geocoding_accuracy
    const percent = Math.round(accuracy * 100)
    let status = 'danger'
    if (accuracy > this.accuracySuccessValue) status = 'success'
    else if (accuracy > this.accuracyWarningValue) status = 'warning'

    const accuracyBlock = this.element.querySelector('#geocoding_accuracy')
    const failBlock = this.element.querySelector('#geocoding_fail')
    const noneBlock = this.element.querySelector('#no_geocoding_accuracy')
    const levelBlock = this.element.querySelector('#geocoding_level')

    failBlock?.classList.add('d-none')
    accuracyBlock?.classList.remove('d-none')
    noneBlock?.classList.add('d-none')
    levelBlock?.classList.remove('d-none')

    const progressBar = this.element.querySelector('#geocoding-progress .progress-bar')
    if (progressBar) {
      progressBar.style.width = `${percent}%`
      progressBar.classList.remove('progress-bar-success', 'progress-bar-warning', 'progress-bar-danger')
      progressBar.classList.add(`progress-bar-${status}`)
      const span = progressBar.querySelector('span')
      if (span) span.textContent = `${percent}%`
    }

    this._setInputValue('destination[geocoding_accuracy]', accuracy)
    this._displayGeocodingLevel(destination.geocoding_level)
  }

  _displayGeocodingFailure () {
    this.element.querySelector('#geocoding_fail')?.classList.remove('d-none')
    this.element.querySelector('#geocoding_accuracy')?.classList.add('d-none')
    this.element.querySelector('#no_geocoding_accuracy')?.classList.add('d-none')
    this.element.querySelector('#geocoding_level')?.classList.add('d-none')
    this._setInputValue('destination[geocoding_accuracy]', '')
    this._setInputValue('destination[geocoding_level]', '')
  }

  _displayGeocodingNotApplicable () {
    this.element.querySelector('#no_geocoding_accuracy')?.classList.remove('d-none')
    this.element.querySelector('#geocoding_accuracy')?.classList.add('d-none')
    this.element.querySelector('#geocoding_fail')?.classList.add('d-none')
    this.element.querySelector('#geocoding_level')?.classList.add('d-none')
    this._setInputValue('destination[geocoding_accuracy]', '')
    this._setInputValue('destination[geocoding_level]', '')
  }

  _displayGeocodingLevel (level) {
    const levelBlock = this.element.querySelector('#geocoding_level')
    const noneBlock = this.element.querySelector('#no_geocoding_accuracy')
    levelBlock?.classList.remove('d-none')

    if (level === 'point') {
      noneBlock?.classList.remove('d-none')
    } else {
      noneBlock?.classList.add('d-none')
    }

    this._setInputValue('destination[geocoding_level]', level || '')

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
