// Copyright © Cartoway
// Compare page: change reference, add/remove plannings via URL.
import { Controller } from "@hotwired/stimulus"
import { planningCompareUrl } from "lib/planning_compare_url"

export default class extends Controller {
  static targets = ["addSelect"]
  static values = {
    ids: Array,
    ref: Number
  }

  setReference (event) {
    const refId = event.currentTarget.value
    if (!refId) return
    window.location.href = planningCompareUrl(this.idsValue, refId)
  }

  remove (event) {
    event.preventDefault()
    const planningId = String(event.currentTarget.dataset.planningId || "")
    const ids = this.idsValue.map(String).filter((id) => id !== planningId)
    if (ids.length < 2) return
    const refId = String(this.refValue) === planningId ? ids[0] : this.refValue
    window.location.href = planningCompareUrl(ids, refId)
  }

  add (event) {
    event.preventDefault()
    const select = this.hasAddSelectTarget ? this.addSelectTarget : event.currentTarget
    const planningId = select.value
    if (!planningId) return
    if (this.idsValue.map(String).includes(planningId)) {
      select.value = ""
      return
    }
    window.location.href = planningCompareUrl([...this.idsValue, planningId], this.refValue)
  }
}
