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
import { moveStopsModal } from '../modals/move_stops_modal.js';

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

      // Use MoveStops modal instead of custom modal
      this.showMoveStopsModalForLassoSelection();
    } else {
      // Reset lasso tool when selection is empty
      this.disableLasso();
    }
  }

    /**
   * Show MoveStops modal for lasso selection
   * This method uses the existing MoveStops modal and simulates stop selection
   */
  showMoveStopsModalForLassoSelection() {
    // Extract stops from selected layers
    const selectedStops = [];

    if (this.selectedLayers && this.selectedLayers.length > 0) {
      this.selectedLayers.forEach((layer) => {
        if (layer.properties && layer.properties.stop_id && layer.properties.route_id) {
          selectedStops.push({
            stop_id: layer.properties.stop_id,
            route_id: layer.properties.route_id
          });
        }
      });
    }

    if (selectedStops.length === 0) {
      return;
    }

    // Open modal by providing selected stop IDs (server will infer primary route)
    moveStopsModal.showModalForStops(selectedStops.map(s => s.stop_id));

    // Setup automatic selection of lasso-selected stops when modal loads
    this.setupLassoStopSelection(selectedStops);

    // Setup cleanup when modal is hidden
    this.setupLassoCleanup();
  }

  /**
   * Setup automatic selection of lasso-selected stops in the modal
   * @param {Array} selectedStops - Array of selected stops from lasso
   */
  setupLassoStopSelection(selectedStops) {
    const selectedStopIds = selectedStops.map(stop => stop.stop_id);

    // Wait for modal to be fully loaded, then select the stops
    $(moveStopsModal.modalSelector).off('shown.bs.modal.lasso').on('shown.bs.modal.lasso', () => {
      // Select all checkboxes for lasso-selected stops
      selectedStopIds.forEach(stopId => {
        const checkbox = $(`${moveStopsModal.modalSelector} input[name="stop_ids"][value="${stopId}"]`);
        if (checkbox.length > 0) {
          checkbox.prop('checked', true).trigger('change');
        }
      });
    });
  }

  /**
   * Setup cleanup for lasso selection when modal is hidden
   */
  setupLassoCleanup() {
    $(moveStopsModal.modalSelector).off('hidden.bs.modal.lasso').on('hidden.bs.modal.lasso', () => {
      // Clear lasso selection
      this.clearLassoSelection();

      // Disable lasso
      this.disableLasso();

      // Remove custom event handlers
      $(moveStopsModal.modalSelector).off('hidden.bs.modal.lasso');
      $(moveStopsModal.modalSelector).off('shown.bs.modal.lasso');
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

    // Clean up lasso-specific modal behavior
    $(moveStopsModal.modalSelector).off('hidden.bs.modal.lasso');
    $(moveStopsModal.modalSelector).off('shown.bs.modal.lasso');

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
