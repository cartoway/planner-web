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

/**
 * LassoModule - Provides lasso selection capabilities for map layers
 */
export class LassoModule {
  constructor() {
    this.lassoHandler = null;
    this.selectedLayers = [];
    this.isLassoActive = false;
    this.lassoControl = null;
    this.map = null;
    this.planningId = null;
    this.routesLayer = null;
    this.dataExtractor = null;
    this.waitingRoute = null;
    this.refreshRoute = null;
  }

  /**
   * Initialize the lasso functionality
   * @param {Object} mapInstance - Leaflet map instance
   * @param {string} planningIdParam - Planning ID
   * @param {Object} routesLayerInstance - Routes layer instance
   * @param {Function} routeWaitingFunc - Function to handle route waiting state
   * @param {Function} refreshRouteFunc - Function to refresh routes
   * @returns {Object|null} Lasso control instance or null
   */
  initLasso(mapInstance, planningIdParam, routesLayerInstance, routeWaitingFunc, refreshRouteFunc) {
    if (this.lassoHandler && this.planningId !== planningIdParam) {
      this.destroy();
    }

    if (this.lassoHandler && this.planningId === planningIdParam) {
      return this.lassoControl;
    }

    this.map = mapInstance;
    this.planningId = planningIdParam;
    this.routesLayer = routesLayerInstance;

    // Store the functions passed from plannings.js
    this.waitingRoute = routeWaitingFunc;
    this.refreshRoute = refreshRouteFunc;

    // Initialize data extractor if available
    if (typeof MapDataExtractor !== 'undefined') {
      this.dataExtractor = MapDataExtractor;
      this.dataExtractor.initialize(this.map, this.routesLayer);
    }

    // Create lasso handler with custom layer detection
    this.lassoHandler = L.lasso(this.map, {
      polygon: {
        color: '#198754',
        weight: 5,
        fillColor: '#a3cfbb',
        fillOpacity: 0.3,
        dashArray: '20, 15'
      },
      intersect: false
    });

    this.map.on('lasso.finished', (event) => {
      if (typeof LassoSelection === 'function') {
        LassoSelection(event, this.map, document.querySelector('.sidebar'));
      } else {
        this.onLassoFinished(event);
      }
    });

    return this.addLassoControl();
  }

  /**
   * Add lasso control to the map
   * @returns {Object|null} Lasso control instance or null
   */
  addLassoControl() {
    if (this.lassoControl) {
      return this.lassoControl;
    }

    // Check if the existing selection system already has a lasso control
    const existingLassoControl = document.querySelector('.leaflet-control-lasso');
    if (existingLassoControl) {
      return null;
    }

    // Capture reference to LassoModule instance
    const lassoModuleInstance = this;

    const LassoControlClass = L.Control.extend({
      options: {
        position: 'topleft'
      },

      onAdd() {
        const container = L.DomUtil.create('div', 'leaflet-bar leaflet-control leaflet-control-lasso');
        container.style.backgroundColor = 'white';
        container.style.width = '28px';
        container.style.height = '26px';

        const button = L.DomUtil.create('a', '', container);
        button.title = I18n.t('plannings.edit.lasso.toggle');

        const icon = L.DomUtil.create('i', 'lasso-icon fa fa-mouse-pointer fa-lg', button);
        icon.style.marginLeft = '2px';

        container.onclick = () => {
          lassoModuleInstance.toggleLasso();
        };

        return container;
      }
    });

    this.lassoControl = new LassoControlClass();
    this.map.addControl(this.lassoControl);
    return this.lassoControl;
  }

  /**
   * Toggle lasso functionality on/off
   */
  toggleLasso() {
    // Check if the existing selection system is active
    const existingLassoControl = document.querySelector('.leaflet-control-lasso');
    if (existingLassoControl && existingLassoControl.classList.contains('active')) {
      // Use the existing system's toggle
      existingLassoControl.click();
      return;
    }

    // Use our own toggle
    if (this.isLassoActive) {
      this.disableLasso();
    } else {
      this.enableLasso();
    }
  }

  /**
   * Enable lasso functionality
   */
  enableLasso() {
    this.isLassoActive = true;
    this.lassoHandler.enable();

    // Update existing lasso control if it exists
    const existingLassoControl = document.querySelector('.leaflet-control-lasso');
    if (existingLassoControl) {
      existingLassoControl.querySelector('i').classList.add('fa-crosshairs');
      existingLassoControl.querySelector('i').classList.remove('fa-mouse-pointer');
    } else {
      $('.lasso-icon').addClass('fa-crosshairs').removeClass('fa-mouse-pointer');
    }

    this.map.getContainer().style.cursor = 'crosshair';
  }

  /**
   * Disable lasso functionality
   */
  disableLasso() {
    this.isLassoActive = false;
    this.lassoHandler.disable();

    // Update existing lasso control if it exists
    const existingLassoControl = document.querySelector('.leaflet-control-lasso');
    if (existingLassoControl) {
      existingLassoControl.querySelector('i').classList.remove('fa-crosshairs');
      existingLassoControl.querySelector('i').classList.add('fa-mouse-pointer');
    } else {
      $('.lasso-icon').removeClass('fa-crosshairs').addClass('fa-mouse-pointer');
    }

    this.map.getContainer().style.cursor = '';

    // Clear selection without calling clearLassoSelection to avoid recursion
    if (this.selectedLayers) {
      this.selectedLayers.forEach((layer) => {
        if (layer.getElement && layer.getElement()) {
          const element = layer.getElement();
          if (element && element.classList) {
            element.classList.remove('leaflet-lasso-selected');
          }
        }
      });
      this.selectedLayers = [];
    }
  }

  /**
   * Handle lasso selection finished event
   * @param {Object} event - Lasso finished event
   */
  onLassoFinished(event) {
    this.selectedLayers = event.layers;

    if (this.selectedLayers.length > 0) {
      // Highlight selected layers
      this.selectedLayers.forEach((layer) => {
        if (layer.getElement) {
          layer.getElement().classList.add('leaflet-lasso-selected');
        }
      });

      // Show selection info
      this.showLassoInfoModal();
    } else {
      // Reset lasso tool when selection is empty
      this.disableLasso();
    }
  }

  /**
   * Show lasso information modal
   */
  showLassoInfoModal() {
    // Remove existing modal
    $('#lasso-info-modal').remove();

    // Extract stop IDs from selected layers
    const stopIds = [];

    if (this.selectedLayers && this.selectedLayers.length > 0) {
      this.selectedLayers.forEach((layer) => {
        if (layer.properties && layer.properties.stop_id) {
          stopIds.push(layer.properties.stop_id);
        }
      });
    }

    // Prepare AJAX parameters
    const ajaxParams = {
      planning_id: this.planningId,
      stop_ids: stopIds.join(',')
    };

    // Load modal template via AJAX
    $.ajax({
      url: `/plannings/${this.planningId}/selection_details.html`,
      type: 'GET',
      data: ajaxParams,
      dataType: 'html',
      beforeSend: beforeSendWaiting,
      success: (modalHtml) => {
        $('body').append(modalHtml);

        const modal = $('#lasso-info-modal');
        this.setupModalEventHandlers(modal);
        modal.modal('show');
      },
      error: ajaxError,
      complete: completeAjaxMap
    });
  }

  /**
   * Setup modal event handlers
   * @param {Object} modal - Modal jQuery element
   */
  setupModalEventHandlers(modal) {
    modal.on('click', '#clear-lasso-selection', (e) => {
      e.preventDefault();
      this.clearLassoSelection();
    });

    modal.on('click', '#move-stops-btn', (e) => {
      e.preventDefault();
      this.moveSelectedStopsToRoute();
    });

    const routeSelect = modal.find('#route-select');
    if (routeSelect.length > 0) {
      routeSelect.select2({
        placeholder: I18n.t('plannings.edit.lasso.select_route_placeholder'),
        allowClear: true,
        minimumResultsForSearch: -1,
        templateResult: (route) => {
          const routeColor = $(route.element).data('route-color');
          const routeName = route.text;

          if (routeColor) {
            return $(`<span><div class="color_small" style="background:${routeColor};"></div>${routeName}</span>`);
          }
          return routeName;
        },
        templateSelection: (route) => {
          const routeColor = $(route.element).data('route-color');
          const routeName = route.text;

          if (routeColor) {
            return $(`<span><div class="color_small" style="background:${routeColor};"></div>${routeName}</span>`);
          }
          return routeName;
        }
      });

      routeSelect.on('change', function() {
        const routeId = $(this).val();
        modal.find('#move-stops-btn').prop('disabled', !routeId);
      });
    }

    modal.on('hidden.bs.modal', () => {
      this.disableLasso();
    });
  }

  /**
   * Move selected stops to a target route
   */
  moveSelectedStopsToRoute() {
    if (!this.selectedLayers || this.selectedLayers.length === 0) {
      return;
    }

    const targetRouteId = $('#route-select').val();
    if (!targetRouteId) {
      alert(I18n.t('plannings.edit.lasso.please_select_route'));
      return;
    }

    let stopIds = [];
    const sourceRouteIds = [];

    // Use MapDataExtractor to get stop IDs if available
    if (this.dataExtractor) {
      const selectedIds = this.selectedLayers
        .map((layer) => layer.properties.stop_id)
        .filter((id) => id);

      const allMarkers = this.dataExtractor.extractMarkersData();
      const selectedMarkers = allMarkers.filter((marker) => {
        return selectedIds.includes(marker.id) && marker.type === 'stop';
      });

      stopIds = selectedMarkers.map((marker) => marker.id);

      // Get source route IDs from selected markers
      selectedMarkers.forEach((marker) => {
        if (marker.route_id) {
          sourceRouteIds.push(marker.route_id);
        }
      });
    } else {
      // Fallback to original method
      const selectedStops = this.selectedLayers.filter((layer) => {
        return layer.properties && layer.properties.stop_id;
      });

      stopIds = selectedStops.map((layer) => layer.properties.stop_id);

      // Get source route IDs from selected layers
      selectedStops.forEach((layer) => {
        if (layer.properties && layer.properties.route_id) {
          sourceRouteIds.push(layer.properties.route_id);
        }
      });
    }

    if (stopIds.length === 0) {
      return;
    }

    // Create array of unique route IDs (source routes + target route)
    const allRouteIds = sourceRouteIds.concat([targetRouteId]);
    const uniqueRouteIds = allRouteIds.filter((item, pos) => {
      return allRouteIds.indexOf(item) === pos;
    });

    // Send AJAX request to move stops
    $.ajax({
      url: `/plannings/${this.planningId}/${targetRouteId}/move.json`,
      type: 'PATCH',
      data: {
        stop_ids: stopIds
      },
      beforeSend: () => {
        beforeSendWaiting();
        uniqueRouteIds.forEach((routeId) => {
          this.waitingRoute(routeId);
        });
      },
      success: (data, _status, xhr) => {
        if (xhr.status === 204) return;

        const routesToRefresh = data.route_ids || uniqueRouteIds;

        routesToRefresh.forEach((route_id) => {
          this.refreshRoute(this.planningId, route_id);
        });

        this.routesLayer.refreshRoutes(routesToRefresh, data.summary.routes);
        this.clearLassoSelection();
        notice(I18n.t('plannings.edit.lasso.stops_moved_success'));
      },
      error: ajaxError,
      complete: completeAjaxMap
    });
  }

  /**
   * Clear lasso selection
   */
  clearLassoSelection() {
    if (this.selectedLayers) {
      this.selectedLayers.forEach((layer) => {
        if (layer.getElement && layer.getElement()) {
          const element = layer.getElement();
          if (element && element.classList) {
            element.classList.remove('leaflet-lasso-selected');
          }
        }
      });
      this.selectedLayers = [];
    }

    // Close info modal
    $('#lasso-info-modal').modal('hide');
  }

  /**
   * Destroy lasso module and clean up resources
   */
  destroy() {
    if (this.lassoHandler) {
      this.lassoHandler.disable();
      this.lassoHandler = null;
    }

    if (this.lassoControl) {
      if (this.map && this.map.removeControl) {
        this.map.removeControl(this.lassoControl);
      }
      this.lassoControl = null;
    }

    this.clearLassoSelection();

    this.map = null;
    this.planningId = null;
    this.routesLayer = null;
    this.dataExtractor = null;
    this.waitingRoute = null;
    this.refreshRoute = null;
    this.selectedLayers = [];
    this.isLassoActive = false;
  }

  /**
   * Get lasso control reference
   * @returns {Object|null} Lasso control instance
   */
  getControl() {
    return this.lassoControl;
  }
}

// Create and export a singleton instance for backward compatibility
export const lassoModule = new LassoModule();
