// Copyright © Cartoway
// Show/hide router option fields from the selected router (replaces Paloma routerOptionsSelect on v2).
import { Controller } from "@hotwired/stimulus"

const OPTION_IDS = [
  ["router_options_approach_input", "approach"],
  ["router_options_snap_input", "snap"],
  ["router_options_strict_restriction_input", "strict_restriction"],
  ["router_options_traffic_input", "traffic"],
  ["router_options_track_input", "track"],
  ["router_options_low_emission_zone_input", "low_emission_zone"],
  ["router_options_motorway_input", "motorway"],
  ["router_options_toll_input", "toll"],
  ["router_options_trailers_input", "trailers"],
  ["router_options_weight_input", "weight"],
  ["router_options_weight_per_axle_input", "weight_per_axle"],
  ["router_options_height_input", "height"],
  ["router_options_width_input", "width"],
  ["router_options_length_input", "length"],
  ["router_options_hazardous_goods_input", "hazardous_goods"],
  ["router_options_max_walk_distance_input", "max_walk_distance"]
]

export default class extends Controller {
  connect () {
    this.apply(this.routerValue())
  }

  change (event) {
    const el = event.target
    if (!el || el.name !== "vehicle_usage[vehicle][router]") return
    this.apply(el.value)
  }

  routerValue () {
    const sel = this.element.querySelector('select[name="vehicle_usage[vehicle][router]"]')
    return sel ? sel.value : ""
  }

  apply (selectedValue) {
    if (!selectedValue) return
    const parts = String(selectedValue).split("_")
    const routerId = parts.length === 3 ? parts[1] : parts[0]
    const options = this.routersOptions()[routerId]
    if (!options) return
    OPTION_IDS.forEach(([id, key]) => this.toggle(id, !!options[key]))
  }

  routersOptions () {
    try {
      const cfg = JSON.parse(this.element.getAttribute("data-v2-js-config") || "{}")
      return cfg.routers_options || {}
    } catch (e) {
      return {}
    }
  }

  toggle (id, show) {
    const el = this.element.querySelector(`#${id}`)
    if (!el) return
    el.classList.toggle("router-option-disabled", !show)
    el.querySelectorAll("input, select, textarea").forEach((input) => {
      input.disabled = !show
    })
  }
}
