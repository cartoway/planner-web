// Copyright © Cartoway
// Radio "no/yes" that shows/hides the numeric overload multiplier.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["yes", "no", "input"]

  connect () {
    this.sync()
  }

  sync () {
    if (!this.hasInputTarget) return
    const yes = this.hasYesTarget && this.yesTarget.checked
    this.inputTarget.classList.toggle("d-none", !yes)
    if (!yes) {
      const none = this.hasNoTarget && this.noTarget.checked
      this.inputTarget.value = none ? "0" : "-1"
      this.inputTarget.required = false
    } else if (Number(this.inputTarget.value) <= 0) {
      this.inputTarget.value = this.inputTarget.placeholder > "0" ? "" : "1"
    }
  }
}
