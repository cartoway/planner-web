import { Controller } from '@hotwired/stimulus'

// Native file input styled like v1 bootstrap-filestyle (primary button + filename).
export default class extends Controller {
  static targets = ['input', 'name']

  changed () {
    if (!this.hasNameTarget || !this.hasInputTarget) return
    const files = this.inputTarget.files
    this.nameTarget.value = files?.length
      ? Array.from(files).map((f) => f.name).join(', ')
      : ''
  }
}
