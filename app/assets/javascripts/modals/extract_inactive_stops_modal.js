// Copyright © Cartoway, 2026
//
// This file is part of Cartoway Planner.
//
'use strict';

import { ajaxError, beforeSendWaiting, completeAjaxMap } from '../ajax.js';
import { panelLoading } from '../plannings.js';

/**
 * ExtractInactiveStopsModal - Move inactive StopVisits from vehicle routes to out-of-route
 */
export class ExtractInactiveStopsModal {
  constructor() {
    this.planningId = null;
    this.routesLayer = null;
    this.refreshSidebarRoute = null;
    this.updatePlanningDataHeader = null;
    this.modalSelector = '#planning-extract-inactive-stops-modal';
    this.stopMoveUsable = true;
    this.isInitialized = false;
  }

  initialize(options) {
    this.planningId = options.planningId;
    this.routesLayer = options.routesLayer;
    this.refreshSidebarRoute = options.refreshSidebarRoute;
    this.updatePlanningDataHeader = options.updatePlanningDataHeader || function() {};
    this.stopMoveUsable = options.stopMoveUsable !== false;

    if (!this.isInitialized) {
      this.setupEventHandlers();
      this.isInitialized = true;
    }

    this.applyConfirmButtonVisibility();
  }

  setupEventHandlers() {
    $(this.modalSelector).off('show.bs.modal.extractInactive').on('show.bs.modal.extractInactive', () => {
      if (!this.stopMoveUsable) {
        return;
      }

      $(`${this.modalSelector} .modal-body`).html(
        '<div class="spinner"><i class="fa fa-spin fa-2x fa-spinner"></i></div>'
      );

      $.ajax({
        url: `/plannings/${this.planningId}/extract_inactive_stops_modal.js`,
        dataType: 'script',
        error: ajaxError
      });
    });

    $(this.modalSelector).off('hidden.bs.modal.extractInactive').on('hidden.bs.modal.extractInactive', () => {
      $(`${this.modalSelector} .modal-body`).empty();
      window.extractInactiveStopsData = null;
    });

    $('#extract-inactive-stops-modal-confirm').off('click.extractInactive').on('click.extractInactive', () => {
      if (!this.stopMoveUsable) {
        return;
      }
      this.handleExtractInactiveStops();
    });

    $(document).off('extract-inactive-stops:content-updated').on('extract-inactive-stops:content-updated', () => {
      try {
        $('[type="checkbox"][data-toggle="disable-multiple-actions"]').toggleMultipleActions();

        $(`${this.modalSelector} .move-stops-stop-id`)
          .off('change.extractInactivePermissions')
          .on('change.extractInactivePermissions', () => {
            this.updateStopsCount();
            this.applyConfirmButtonVisibility();
          });

        this.updateStopsCount();
        this.applyConfirmButtonVisibility();
      } catch (e) {
        // no-op
      }
    });

    $(this.modalSelector).off('click.extractInactiveSelect', '.extract-inactive-stops-selection [data-selection]')
      .on('click.extractInactiveSelect', '.extract-inactive-stops-selection [data-selection]', (event) => {
        this.applySelection($(event.currentTarget).data('selection'));
      });
  }

  applySelection(action) {
    const $checkboxes = $(`${this.modalSelector} #extract-inactive-stops .move-stops-stop-id:visible`);
    let $lastChanged = $();

    $checkboxes.each(function() {
      const $checkbox = $(this);
      if (action === 'all') {
        $checkbox.prop('checked', true);
      } else if (action === 'none') {
        $checkbox.prop('checked', false);
      } else if (action === 'reverse') {
        $checkbox.prop('checked', !$checkbox.prop('checked'));
      }
      $lastChanged = $checkbox;
    });

    if ($lastChanged.length) {
      $lastChanged.trigger('change');
    } else {
      this.updateStopsCount();
      this.applyConfirmButtonVisibility();
    }
  }

  updateStopsCount() {
    const checkedStops = $(`${this.modalSelector} .move-stops-stop-id:checked:visible`).length;
    $('#extract-inactive-stops_count').text(checkedStops);
  }

  applyConfirmButtonVisibility() {
    const $confirmBtn = $('#extract-inactive-stops-modal-confirm');
    const hasSelectedStops = $(`${this.modalSelector} .move-stops-stop-id:checked:visible`).length > 0;
    const enabled = this.stopMoveUsable && hasSelectedStops;

    if (this.stopMoveUsable) {
      $confirmBtn.show().prop('disabled', !enabled);
    } else {
      $confirmBtn.hide();
    }
  }

  handleExtractInactiveStops() {
    const data = window.extractInactiveStopsData || {};
    const outOfRouteId = data.outOfRouteId;
    if (!outOfRouteId) {
      return;
    }

    const stopIds = $(this.modalSelector)
      .find('form input[name="stop_ids"]:checked:visible')
      .map(function() { return $(this).val(); })
      .toArray();

    if (stopIds.length === 0) {
      return;
    }

    $.ajax({
      type: 'PATCH',
      url: `/plannings/${this.planningId}/${outOfRouteId}/move.json`,
      data: {
        stop_ids: stopIds,
        index: -1
      },
      beforeSend: () => {
        beforeSendWaiting();
        $(this.modalSelector).modal('hide');

        const impactedRouteIds = new Set([outOfRouteId]);
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
        if (xhr.status === 204) {
          return;
        }

        data.route_ids.forEach((routeId) => {
          this.refreshSidebarRoute(this.planningId, routeId);
        });

        if (this.routesLayer && this.routesLayer.refreshRoutes) {
          this.routesLayer.refreshRoutes(data.route_ids, data.summary.routes);
        }

        this.updatePlanningDataHeader();
      },
      complete: completeAjaxMap
    });
  }
}

export const extractInactiveStopsModal = new ExtractInactiveStopsModal();
