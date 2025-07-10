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

import { ajaxError, beforeSendWaiting, completeAjaxMap } from './ajax';

/******************
 * LassoModule
 *
 */
export const LassoModule = (function() {
  var lassoHandler = null;
  var selectedLayers = [];
  var isLassoActive = false;
  var lassoControl = null;
  var map = null;
  var planningId = null;
  var routesLayer = null;
  var dataExtractor = null;
  var waitingRoute = null;
  var refreshRoute = null;

  const initLasso = function(mapInstance, planningIdParam, routesLayerInstance, routeWaitingFunc, refreshRouteFunc) {
    if (lassoHandler) {
      return; // Already initialized
    }

    map = mapInstance;
    planningId = planningIdParam;
    routesLayer = routesLayerInstance;

    // Store the functions passed from plannings.js
    waitingRoute = routeWaitingFunc;
    refreshRoute = refreshRouteFunc;

    // Initialize data extractor if available
    if (typeof MapDataExtractor !== 'undefined') {
      dataExtractor = MapDataExtractor;
      dataExtractor.initialize(map, routesLayer);
    }

    // Create lasso handler with custom layer detection
    lassoHandler = L.lasso(map, {
      polygon: {
        color: '#198754',
        weight: 5,
        fillColor: '#a3cfbb',
        fillOpacity: 0.3,
        dashArray: '20, 15'
      },
      intersect: false
    });

    map.on('lasso.finished', function(event) {
      if (typeof LassoSelection === 'function') {
        LassoSelection(event, map, document.querySelector('.sidebar'));
      } else {
        onLassoFinished(event);
      }
    });
    addLassoControl();

    return this;
  }

  const addLassoControl = function() {
    if (lassoControl) {
      return; // Already added
    }

    // Check if the existing selection system already has a lasso control
    var existingLassoControl = document.querySelector('.leaflet-lasso');
    if (existingLassoControl) {
      return; // Don't create a duplicate control
    }

    lassoControl = L.Control.extend({
      options: {
        position: 'topleft'
      },

      onAdd: function() {
        var container = L.DomUtil.create('div', 'leaflet-bar leaflet-control leaflet-control-lasso');
        container.style.backgroundColor = 'white';
        container.style.width = '28px';
        container.style.height = '26px';

        var button = L.DomUtil.create('a', '', container);
        button.title = I18n.t('plannings.edit.lasso.toggle');

        var icon = L.DomUtil.create('i', 'lasso-icon fa fa-mouse-pointer fa-lg', button);
        icon.style.marginLeft = '2px';

        container.onclick = function() {
          toggleLasso();
        };

        return container;
      }
    });

    map.addControl(new lassoControl());
  }

  const toggleLasso = function() {
    // Check if the existing selection system is active
    var existingLassoControl = document.querySelector('.leaflet-lasso');
    if (existingLassoControl && existingLassoControl.classList.contains('active')) {
      // Use the existing system's toggle
      existingLassoControl.click();
      return;
    }

    // Use our own toggle
    if (isLassoActive) {
      disableLasso();
    } else {
      enableLasso();
    }
  }

  const enableLasso = function() {
    isLassoActive = true;
    lassoHandler.enable();

    // Update existing lasso control if it exists
    var existingLassoControl = document.querySelector('.leaflet-lasso');
    if (existingLassoControl) {
      existingLassoControl.querySelector('i').classList.add('fa-crosshairs');
      existingLassoControl.querySelector('i').classList.remove('fa-mouse-pointer');
    } else {
      $('.lasso-icon').addClass('fa-crosshairs').removeClass('fa-mouse-pointer');
    }

    map.getContainer().style.cursor = 'crosshair';
  }

  const disableLasso = function() {
    isLassoActive = false;
    lassoHandler.disable();

    // Update existing lasso control if it exists
    var existingLassoControl = document.querySelector('.leaflet-lasso');
    if (existingLassoControl) {
      existingLassoControl.querySelector('i').classList.remove('fa-crosshairs');
      existingLassoControl.querySelector('i').classList.add('fa-mouse-pointer');
    } else {
      $('.lasso-icon').removeClass('fa-crosshairs').addClass('fa-mouse-pointer');
    }

    map.getContainer().style.cursor = '';

    // Clear selection without calling clearLassoSelection to avoid recursion
    if (selectedLayers) {
      selectedLayers.forEach(function(layer) {
        if (layer.getElement && layer.getElement()) {
          var element = layer.getElement();
          if (element && element.classList) {
            element.classList.remove('leaflet-lasso-selected');
          }
        }
      });
      selectedLayers = [];
    }
  }

  const onLassoFinished = function(event) {
    selectedLayers = event.layers;

    if (selectedLayers.length > 0) {
      // Highlight selected layers
      selectedLayers.forEach(function(layer) {
        if (layer.getElement) {
          layer.getElement().classList.add('leaflet-lasso-selected');
        }
      });

      // Show selection info
      showLassoInfoModal();
    } else {
      // Reset lasso tool when selection is empty
      disableLasso();
    }
  }

  const showLassoInfoModal = function() {
    // Remove existing modal
    $('#lasso-info-modal').remove();

    // Extract stop IDs from selected layers
    var stopIds = [];

    if (selectedLayers && selectedLayers.length > 0) {
      selectedLayers.forEach(function(layer) {
        if (layer.properties && layer.properties.stop_id) {
          stopIds.push(layer.properties.stop_id);
        }
      });
    }

    // Prepare AJAX parameters
    var ajaxParams = {
      planning_id: planningId,
      stop_ids: stopIds.join(',')
    };

    // Load modal template via AJAX
    $.ajax({
      url: '/plannings/' + planningId + '/selection_details.html',
      type: 'GET',
      data: ajaxParams,
      dataType: 'html',
      beforeSend: beforeSendWaiting,
      success: function(modalHtml) {
        $('body').append(modalHtml);

        var modal = $('#lasso-info-modal');
        setupModalEventHandlers(modal);
        modal.modal('show');
      },
      error: ajaxError,
      complete: completeAjaxMap
    });
  }



  const setupModalEventHandlers = function(modal) {
    modal.on('click', '#clear-lasso-selection', function(e) {
      e.preventDefault();
      clearLassoSelection();
    });

    modal.on('click', '#move-stops-btn', function(e) {
      e.preventDefault();
      moveSelectedStopsToRoute();
    });

    var routeSelect = modal.find('#route-select');
    if (routeSelect.length > 0) {
      routeSelect.select2({
        placeholder: I18n.t('plannings.edit.lasso.select_route_placeholder'),
        allowClear: true,
        minimumResultsForSearch: -1,
        templateResult: function(route) {
          var routeColor = $(route.element).data('route-color');
          var routeName = route.text;

          if (routeColor) {
            return $('<span><div class="color_small" style="background:' + routeColor + ';"></div>' + routeName + '</span>');
          }
          return routeName;
        },
        templateSelection: function(route) {
          var routeColor = $(route.element).data('route-color');
          var routeName = route.text;

          if (routeColor) {
            return $('<span><div class="color_small" style="background:' + routeColor + ';"></div>' + routeName + '</span>');
          }
          return routeName;
        }
      });

      routeSelect.on('change', function(e) {
        var routeId = $(this).val();
        modal.find('#move-stops-btn').prop('disabled', !routeId);
      });
    }

    modal.on('hidden.bs.modal', function() {
      disableLasso();
    });
  }

  const moveSelectedStopsToRoute = function() {
    if (!selectedLayers || selectedLayers.length === 0) {
      return;
    }

    var targetRouteId = $('#route-select').val();
    if (!targetRouteId) {
      alert(I18n.t('plannings.edit.lasso.please_select_route'));
      return;
    }

    var stopIds = [];
    var sourceRouteIds = [];

    // Use MapDataExtractor to get stop IDs if available
    if (dataExtractor) {
      var selectedIds = selectedLayers.map(function(layer) {
        return layer.properties.stop_id;
      }).filter(function(id) { return id; });

      var allMarkers = dataExtractor.extractMarkersData();
      var selectedMarkers = allMarkers.filter(function(marker) {
        return selectedIds.includes(marker.id) && marker.type === 'stop';
      });

      stopIds = selectedMarkers.map(function(marker) {
        return marker.id;
      });

      // Get source route IDs from selected markers
      selectedMarkers.forEach(function(marker) {
        if (marker.route_id) {
          sourceRouteIds.push(marker.route_id);
        }
      });
    } else {
      // Fallback to original method
      var selectedStops = selectedLayers.filter(function(layer) {
        return layer.properties && layer.properties.stop_id;
      });

      stopIds = selectedStops.map(function(layer) {
        return layer.properties.stop_id;
      });

      // Get source route IDs from selected layers
      selectedStops.forEach(function(layer) {
        if (layer.properties && layer.properties.route_id) {
          sourceRouteIds.push(layer.properties.route_id);
        }
      });
    }

    if (stopIds.length === 0) {
      return;
    }

    // Create array of unique route IDs (source routes + target route)
    var allRouteIds = sourceRouteIds.concat([targetRouteId]);
    var uniqueRouteIds = allRouteIds.filter(function(item, pos) {
      return allRouteIds.indexOf(item) === pos;
    });

    // Send AJAX request to move stops
    $.ajax({
      url: '/plannings/' + planningId + '/' + targetRouteId + '/move.json',
      type: 'PATCH',
      data: {
        stop_ids: stopIds
      },
      beforeSend: function() {
        beforeSendWaiting();
        uniqueRouteIds.forEach(function(routeId) {
          waitingRoute(routeId);
        });
      },
      success: function(data, _status, xhr) {
        if (xhr.status === 204) return;

        var routesToRefresh = data.route_ids || uniqueRouteIds;

        routesToRefresh.forEach(function(route_id) {
          refreshRoute(planningId, route_id);
        });

        routesLayer.refreshRoutes(routesToRefresh, data.summary.routes);
        clearLassoSelection();
        notice(I18n.t('plannings.edit.lasso.stops_moved_success'));
      },
      error: ajaxError,
      complete: completeAjaxMap
    });
  }

  const clearLassoSelection = function() {
    if (selectedLayers) {
      selectedLayers.forEach(function(layer) {
        if (layer.getElement && layer.getElement()) {
          var element = layer.getElement();
          if (element && element.classList) {
            element.classList.remove('leaflet-lasso-selected');
          }
        }
      });
      selectedLayers = [];
    }

    // Close info modal
    $('#lasso-info-modal').modal('hide');
  }

  const destroy = function() {
    if (lassoHandler) {
      lassoHandler.disable();
      lassoHandler = null;
    }

    if (lassoControl) {
      map.removeControl(lassoControl);
      lassoControl = null;
    }

    clearLassoSelection();

    map = null;
    planningId = null;
  }

  // Return public API
  return {
    initLasso: initLasso,
    waitingRoute: waitingRoute,
    refreshRoute: refreshRoute,
    clearLassoSelection: clearLassoSelection,
    moveSelectedStopsToRoute: moveSelectedStopsToRoute,
    destroy: destroy
  };
})();

