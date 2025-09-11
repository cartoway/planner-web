// Copyright © Cartoway, 2025
//
// This file is part of Cartoway Planner.
//
// Cartoway Planner is free software. You can redistribute it and/or
// modify since you respect the terms of the GNU Affero General
// Public License as published by the Free Software Foundation,
// either version 3 of the License, or (at your option) any later version.
//
// Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
// or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Cartoway Planner. If not, see:
// <http://www.gnu.org/licenses/agpl.html>
//

'use strict';

import { ajaxError, beforeSendWaiting, completeAjaxMap } from '../ajax.js';
import { panelLoading } from '../plannings.js';

/**
 * MoveStopsModal - Manages the modal for moving stops between routes
 */
export class MoveStopsModal {
  constructor() {
    this.planningId = null;
    this.routes = [];
    this.vehiclesUsagesMap = {};
    this.quantities = [];
    this.routesLayer = null;
    this.refreshSidebarRoute = null;
    this.mustacheI18n = null;
    this.modalSelector = '#planning-move-stops-modal';
    this.isInitialized = false;
  }

  /**
   * Initialize the move stops modal
   * @param {Object} options - Configuration options
   * @param {string} options.planningId - Planning ID
   * @param {Array} options.routes - Routes array
   * @param {Object} options.vehiclesUsagesMap - Vehicles usages mapping
   * @param {Array} options.quantities - Quantities array
   * @param {Object} options.routesLayer - Routes layer instance
   * @param {Function} options.refreshSidebarRoute - Function to refresh sidebar route
   * @param {Object} options.mustacheI18n - Mustache i18n object
   */
  initialize(options) {
    this.planningId = options.planningId;
    this.routes = options.routes || [];
    this.vehiclesUsagesMap = options.vehiclesUsagesMap || {};
    this.quantities = options.quantities || [];
    this.routesLayer = options.routesLayer;
    this.refreshSidebarRoute = options.refreshSidebarRoute;
    this.mustacheI18n = options.mustacheI18n;

    if (!this.isInitialized) {
      this.setupEventHandlers();
      this.isInitialized = true;
    }
  }

  /**
   * Setup event handlers for the modal
   */
  setupEventHandlers() {
    // Load modal content when opened via data-toggle="modal"
    $(this.modalSelector).off('show.bs.modal.moveStops').on('show.bs.modal.moveStops', (ev) => {
      try {
        const trigger = ev.relatedTarget;
        const routeId = trigger && trigger.getAttribute && trigger.getAttribute('data-route-id');
        if (!routeId) return;

        // Show loading spinner
        $(`${this.modalSelector} .modal-body`).html('<div class="spinner"><i class="fa fa-spin fa-2x fa-spinner"></i></div>').unbind();

        // Ask Rails to render the modal via .js.erb
        $.ajax({
          url: `/plannings/${this.planningId}/move_stops_modal.js`,
          data: { route_id: routeId },
          dataType: 'script',
          error: ajaxError
        });
      } catch (e) {
        // no-op
      }
    });

    // Modal hidden event
    $(this.modalSelector).off('hidden.bs.modal').on('hidden.bs.modal', () => {
      $(this.modalSelector).attr('data-route-id', null);
    });

    // Move stops button click
    $("#move-stops-modal").off('click').on('click', () => {
      this.handleMoveStops();
    });

    // Listen when server injected content is ready, then initialize behaviors
    $(document).off('move-stops:content-updated').on('move-stops:content-updated', () => {
      try {
        // Initialize UI widgets
        $('#move-stops-toggle').toggleSelect();
        $('[type="checkbox"][data-toggle="disable-multiple-actions"]').toggleMultipleActions();

        // Initialize select2 with route colors
        const routesList = window.moveStopsData && window.moveStopsData.availableRoutes || [];
        const templateRoute = (route) => {
          if (route.id) {
            const routeData = routesList.find(r => r.route_id === parseInt(route.id));
            if (routeData) {
              return $("<span><span class='color_small' style='background: " + routeData.color + "'></span>&nbsp;</span>")
                .append($("<span/>").text(route.text));
            }
          }
          return route.text;
        };
        $('#move-route-id').select2({ templateSelection: templateRoute, templateResult: templateRoute, minimumResultsForSearch: -1 });

        // Initialize quantities and computed fields
        if (window.moveStopsData && window.moveStopsData.stops) {
          this.setupModalComponents(window.moveStopsData.stops, routesList);
        }
      } catch (e) {}
    });
  }

  /**
   * Setup modal components (select2, filters, etc.)
   * @param {Array} stops - Stops array
   * @param {Array} availableRoutes - Available target routes
   */
  setupModalComponents(stops, availableRoutes) {
    // Setup route selection dropdown
    this.setupRouteDropdown(availableRoutes);

    // Setup table filters
    $(`${this.modalSelector} input[data-change="filter"]`).filterTable()
      .on('table.filtered', () => {
        this.calculateQuantities(stops);
        this.updateStopsCount();
      });

    // Setup stop selection change handler
    $(`${this.modalSelector} .move-stops-stop-id`).change(() => {
      this.calculateQuantities(stops);
      this.updateStopsCount();
    });

    // Setup route change handler
    $('#move-route-id').change((obj) => {
      const vehicleUsageId = obj.target.selectedOptions[0].attributes['data-vehicle-usage-id'].value;
      this.fillQuantities(stops, vehicleUsageId);
    });

    // Initial quantities calculation
    this.fillQuantities(stops);

    // Set modal height
    $('.overflow-500').css('max-height', ($(document).height() - 440) + 'px');
  }

  /**
   * Setup route dropdown with custom templates
   * @param {Array} availableRoutes - Available target routes
   */
  setupRouteDropdown(availableRoutes) {
    const templateRoute = (route) => {
      if (route.id) {
        const routeData = availableRoutes.find(r => r.route_id === parseInt(route.id));
        if (routeData) {
          return $("<span><span class='color_small' style='background: " + routeData.color + "'></span>&nbsp;</span>")
            .append($("<span/>").text(route.text));
        }
      }
      return route.text;
    };

    $('#move-route-id').select2({
      templateSelection: templateRoute,
      templateResult: templateRoute,
      minimumResultsForSearch: -1
    });
  }

  /**
   * Calculate quantities for selected stops
   * @param {Array} stops - Stops array
   * @param {string} vehicleUsageId - Vehicle usage ID (optional)
   */
  calculateQuantities(stops, vehicleUsageId) {
    vehicleUsageId = vehicleUsageId || $('#move-route-id').find(":selected").attr('data-vehicle-usage-id');

    const $moveStopQuantities = $('#move-stop-quantities');
    const $moveStopGlobalQuantities = $('#move-stop-global-quantities');
    const vehicleQuantities = this.getVehicleQuantities(vehicleUsageId);
    const stopsToMove = this.getAvailableStopsToMoveFrom(stops);
    const globalStops = vehicleQuantities ? stopsToMove.concat(vehicleQuantities) : stopsToMove;

    $moveStopQuantities.calculateQuantities(stopsToMove, this.quantities);
    $moveStopGlobalQuantities.calculateQuantities(globalStops, this.quantities);
  }

  /**
   * Fill quantities in the modal
   * @param {Array} stops - Stops array
   * @param {string} vehicleUsageId - Vehicle usage ID (optional)
   */
  fillQuantities(stops, vehicleUsageId) {
    vehicleUsageId = vehicleUsageId || $('#move-route-id').find(":selected").attr('data-vehicle-usage-id');

    const $moveStopQuantities = $('#move-stop-quantities');
    const $moveStopGlobalQuantities = $('#move-stop-global-quantities');
    const vehicleCapacities = this.getVehicleCapacities(vehicleUsageId);
    const vehicleQuantities = this.getVehicleQuantities(vehicleUsageId);
    const stopsToMove = this.getAvailableStopsToMoveFrom(stops);
    const globalStops = vehicleQuantities ? stopsToMove.concat(vehicleQuantities) : stopsToMove;

    $moveStopGlobalQuantities.empty().fillQuantities({
      vehicleCapacities: vehicleCapacities,
      stops: globalStops,
      controllerParamsQuantities: this.quantities,
      withDuration: true,
      withCapacity: true,
    });

    $moveStopQuantities.empty().fillQuantities({
      vehicleCapacities: vehicleCapacities,
      stops: stopsToMove,
      controllerParamsQuantities: this.quantities,
      withDuration: true,
      withCapacity: true,
    });
  }

  /**
   * Get available stops to move from
   * @param {Array} stops - Stops array
   * @returns {Array} Selected stops
   */
  getAvailableStopsToMoveFrom(stops) {
    const availableStopsToMove = $(`${this.modalSelector} .move-stops-stop-id:checked:visible`);
    const selectedStops = [];

    for (let index = 0; index < availableStopsToMove.length; index++) {
      const element = availableStopsToMove[index];
      const stop = stops.find(stop => stop.stop_id === parseInt(element.value));
      if (stop) {
        selectedStops.push(stop);
      }
    }

    return selectedStops;
  }

  /**
   * Update the active stops count display
   */
  updateStopsCount() {
    const checkedStops = $(`${this.modalSelector} .move-stops-stop-id:checked:visible`).length;
    $('#move-stops_count').text(checkedStops);
  }

  /**
   * Get vehicle quantities
   * @param {string} vehicleUsageId - Vehicle usage ID
   * @returns {Object|null} Vehicle quantities
   */
  getVehicleQuantities(vehicleUsageId) {
    try {
      for (const index of Object.keys(this.vehiclesUsagesMap)) {
        if (this.vehiclesUsagesMap[index].vehicle_usage_id === parseInt(vehicleUsageId)) {
          return { quantities: this.vehiclesUsagesMap[index].vehicle_quantities };
        }
      }
    } catch (exc) {
      return null;
    }
    return null;
  }

  /**
   * Get vehicle capacities
   * @param {string} vehicleUsageId - Vehicle usage ID
   * @returns {Array|null} Vehicle capacities
   */
  getVehicleCapacities(vehicleUsageId) {
    const vehicleUsage = Object.keys(this.vehiclesUsagesMap)
      .map(index => this.vehiclesUsagesMap[index])
      .find(usage => usage.vehicle_usage_id === parseInt(vehicleUsageId));

    if (vehicleUsage && vehicleUsage.default_capacities) {
      return Object.keys(vehicleUsage.default_capacities).map(id => {
        const quantity = this.quantities.find(q => q.id === parseInt(id));
        if (quantity) {
          return {
            id: id,
            capacity: vehicleUsage.default_capacities[id],
            label: quantity.label,
            unitIcon: quantity.unit_icon
          };
        }
      }).filter(element => element);
    }

    return null;
  }

  /**
   * Handle move stops action
   */
  handleMoveStops() {
    const stopIds = $(this.modalSelector)
      .find('form input[name="stop_ids"]:checked:visible')
      .map(function() { return $(this).val(); })
      .toArray();

    const targetRouteId = $("#move-route-id").val();
    const index = $('#move-index').val();

    this.moveStops(stopIds, targetRouteId, index);
  }

  /**
   * Move stops to target route
   * @param {Array} stopIds - Array of stop IDs to move
   * @param {string} targetRouteId - Target route ID
   * @param {string} index - Insertion index
   */
  moveStops(stopIds, targetRouteId, index) {
    $.ajax({
      type: 'PATCH',
      url: `/plannings/${this.planningId}/${targetRouteId}/move.json`,
      data: {
        'stop_ids': stopIds,
        'index': index
      },
      beforeSend: () => {
        beforeSendWaiting();
        $(this.modalSelector).modal('hide');

        const impactedRouteIds = new Set();
        impactedRouteIds.add(targetRouteId);
        $(this.modalSelector)
          .find('form input[name="stop_ids"]:checked:visible')
          .each(function() {
            const routeId = $(this).data('route-id');
            if (routeId) {
              impactedRouteIds.add(routeId);
            }
          });

        impactedRouteIds.forEach(routeId => {
          panelLoading(routeId);
        });
      },
      error: ajaxError,
      success: (data, _status, xhr) => {
        if (xhr.status === 204) return;

        data.route_ids.forEach((route_id) => {
          this.refreshSidebarRoute(this.planningId, route_id);
        });

        if (this.routesLayer && this.routesLayer.refreshRoutes) {
          this.routesLayer.refreshRoutes(data.route_ids, data.summary.routes);
        }
      },
      complete: completeAjaxMap
    });
  }

  /**
   * Show the modal for a specific route
   * @param {string} routeId - Route ID to show modal for
   */
  showModal(routeId) {
    // Show loading spinner immediately
    $(`${this.modalSelector} .modal-body`).html('<div class="spinner"><i class="fa fa-spin fa-2x fa-spinner"></i></div>').unbind();
    $(this.modalSelector).modal('show');

    // Ask Rails to render the modal via .js.erb
    $.ajax({
      url: `/plannings/${this.planningId}/move_stops_modal.js`,
      data: { route_id: routeId },
      dataType: 'script',
      error: ajaxError
    });
  }

  /**
   * Show the modal providing a list of stop IDs (no route id needed)
   * @param {Array<number>} stopIds
   */
  showModalForStops(stopIds) {
    // Show loading spinner immediately
    $(`${this.modalSelector} .modal-body`).html('<div class="spinner"><i class="fa fa-spin fa-2x fa-spinner"></i></div>').unbind();
    $(this.modalSelector).modal('show');

    // Ask Rails to render the modal using stop_ids to infer the primary route
    $.ajax({
      url: `/plannings/${this.planningId}/move_stops_modal.js`,
      data: { stop_ids: (stopIds || []).join(',') },
      dataType: 'script',
      error: ajaxError
    });
  }

  /**
   * Hide the modal
   */
  hideModal() {
    $(this.modalSelector).modal('hide');
  }

  /**
   * Destroy the modal and clean up event handlers
   */
  destroy() {
    $(this.modalSelector).off();
    $("#move-stops-modal").off();
    this.isInitialized = false;
  }
}

// Create and export a singleton instance for backward compatibility
export const moveStopsModal = new MoveStopsModal();
// Expose singleton to window so Rails .js.erb can invoke setup hooks
if (typeof window !== 'undefined') {
  window.moveStopsModal = moveStopsModal;
}
