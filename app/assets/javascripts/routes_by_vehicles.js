// Copyright © Mapotempo, 2013-2017
//
// This file is part of Mapotempo.
//
// Mapotempo is free software. You can redistribute it and/or
// modify since you respect the terms of the GNU Affero General
// Public License as published by the Free Software Foundation,
// either version 3 of the License, or (at your option) any later version.
//
// Mapotempo is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
// or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Mapotempo. If not, see:
// <http://www.gnu.org/licenses/agpl.html>
//
'use strict';

import { RoutesLayer } from './routes_layers'
import {
  templateSelectionColor,
  templateResultColor,
  mapInitialize,
  initializeMapHash
} from './scaffolds'
import {
  beforeSendWaiting,
  completeAjaxMap,
  ajaxError,
  mustache_i18n,
  fake_select2
} from './ajax'

const routesByVehicleShow = function(params) {
  'use strict';

  var colorCodes = params.color_codes.slice(),
    routes = params.routes_array;
  colorCodes.unshift('');

  // Ensure touch compliance with chrome like browser
  L.controlTouchScreenCompliance();

  // sidebar has to be created before map
  var sidebar = L.control.sidebar('show-routes-by-vehicle', {
    position: 'left'
  });
  sidebar.open('routes-by-vehicle-pane');

  var map = mapInitialize(params);
  L.control.attribution({
    prefix: false,
    position: 'bottomleft'
  }).addTo(map);
  L.control.scale({
    imperial: false
  }).addTo(map);

  sidebar.addTo(map);

  var routesLayer = new RoutesLayer(null, {
    unit: params.prefered_unit,
    vehicleId: params.vehicle_id,
    routes: params.routes_array, // Needed for outdated
    colorsByRoute: params.colors_by_route,
    appBaseUrl: '/',
    popupOptions: $.extend({
      isoline: true
    }, params.manage_routes),
    disableClusters: params.disable_clusters
  }).on('clickStop', function(stop) {
    enlightenStop({index: stop.index, routeId: stop.routeId});
  }).addTo(map);

  L.disableClustersControl(map, routesLayer);

  var fitBounds = initializeMapHash(map, true);

  routesLayer.showRoutesWithStore(routes.map(function(route) { return route.route_id; }), null, function() {
    if (fitBounds) {
      var bounds = routesLayer.getBounds();
      if (bounds && bounds.isValid()) {
        map.invalidateSize();
        map.fitBounds(bounds, {
          maxZoom: 15,
          animate: false,
          padding: [20, 20]
        });
      }
    }
  });

  // Used to highlight the current stop (or route if over 1t points) in sidebar routes
  var enlightenStop = function(stop) {
    var target;

    if (stop.index) {
      target = $(".routes [data-route-id='" + stop.routeId + "'] [data-stop-index='" + stop.index + "']");
    } else {
      target = $("[data-stop-id='" + stop.id + "']");
    }

    if (target.length === 0) {
      target = $(".routes [data-route-id='" + stop.routeId + "']");
    } else {
      target.css("background", "orange");
      setTimeout(function() {
        target.css("background", "");
      }, 1500);
    }

    if (target.offset() && (target.offset().top < 0 || target.offset().top > $(".sidebar-content").height())) {
      $(".sidebar-content").animate({
        scrollTop: target.offset().top + $(".sidebar-content").scrollTop() - 100
      });
    }
  };

  var updateColorsForRoutesAndStops = function(i, route) {
    route.colors = $.map(colorCodes, function(color) {
      return {
        color: color,
        selected: route.color === color
      };
    });
    $.each(route.stops, function(i, stop) {
      if (stop.destination && stop.destination.color) {
        stop.destination.color_force = true;
      } else {
        stop.color = route.color;
      }
    });
  };

  const sidebarRoutes = function(data) {
    data.i18n = mustache_i18n;
    $.each(data.routes, function(i, route) {
      updateColorsForRoutesAndStops(i, route);
    });
    $.extend(data, params.manage_routes);

    $('.routes').html(SMT['routes_by_vehicles/show'](data));

    fake_select2($(".color_select"), function(select) {
      select.select2({
        minimumResultsForSearch: -1,
        templateSelection: templateSelectionColor,
        templateResult: templateResultColor,
        formatNoMatches: I18n.t('web.select2.empty_result')
      }).select2("open");
      select.next('.select2-container--bootstrap').addClass('input-sm');
    });

    var $routes = $(".route");

    $routes
      .off('change').on('change', "[name=route\\\[color\\\]]", function() {
        var routeId = $(this).closest('[data-route-id]').attr('data-route-id');
        var planningId = $(this).closest('[data-planning_id]').attr('data-planning_id');
        var color = this.value;
        $.ajax({
          type: 'PUT',
          data: JSON.stringify({
            color: color
          }),
          contentType: 'application/json',
          url: '/api/0.1/plannings/' + planningId + '/routes/' + routeId + '.json',
          success: function() {
            routesLayer.options.colorsByRoute[routeId] = color;
            routesLayer.refreshRoutes([routeId], routes);
          },
          error: ajaxError
        });
        $('li[data-route-id=' + routeId + '] li[data-store_id] > i.fa').css('color', color);
        $('li[data-route-id=' + routeId + '] li[data-stop-id] .number:not(.color_force)').css('background', color);
      })
      .on("click", ".marker", function() {
        var stopIndex = $(this).closest("[data-stop-index]").attr("data-stop-index");
        if (stopIndex) {
          var routeId = $(this).closest("[data-route-id]").attr("data-route-id");
          routesLayer.focus({routeId: routeId, stopIndex: stopIndex});
        } else {
          var storeId = $(this).closest("[data-store_id]").attr("data-store_id");
          if (storeId) {
            routesLayer.focus({storeId: storeId});
          }
        }
        $(this).blur();
        return false;
      });
  };

  $('.btn.extend').click(function() {
    $('.sidebar').toggleClass('extended');
  });

  $.ajax({
    url: '/routes_by_vehicles/' + params.vehicle_id + '.json',
    data: {planning_ids: params.routes_array.map(function(route) {
      return route.planning_id;
    }).join(',')},
    beforeSend: beforeSendWaiting,
    success: sidebarRoutes,
    complete: completeAjaxMap,
    error: ajaxError
  });

  var layerZoning = (new L.FeatureGroup()).addTo(map);
  var zoneGeometry = L.GeoJSON.extend({
    addOverlay: function(zone) {
      var that = this;
      var labelLayer = (new L.layerGroup()).addTo(map);
      var labelMarker;
      this.on('mouseover', function() {
        that.setStyle({
          opacity: 0.9,
          weight: (zone.speed_multiplier === 0) ? 5 : 3
        });
        if (zone.name) labelMarker = L.marker(that.getBounds().getCenter(), {
          icon: L.divIcon({
            className: 'label',
            html: zone.name,
            iconSize: [100, 40]
          })
        }).addTo(labelLayer);
      });
      this.on('mouseout', function() {
        that.setStyle({
          opacity: 0.5,
          weight: (zone.speed_multiplier === 0) ? 5 : 2
        });
        if (labelMarker) labelLayer.removeLayer(labelMarker);
        labelMarker = null;
      });
      return this;
    }
  });

  var displayZoning = function(zoning) {
    $.each(zoning.zones, function(index, zone) {
      var geoJsonLayer = (new zoneGeometry(JSON.parse(zone.polygon))).addOverlay(zone);
      var geom = geoJsonLayer.getLayers()[0];
      if (geom) {
        geom.setStyle((zone.speed_multiplier === 0) ? {
          color: '#FF0000',
          fillColor: '#707070',
          opacity: 0.5,
          weight: 5,
          dashArray: '10, 10',
          fillPattern: stripes
        } : {
          color: (zone.vehicle_id ? params.color : '#707070'),
          fillColor: null,
          opacity: 0.5,
          weight: 2,
          dashArray: 'none',
          fillPattern: null
        });
        geom.addTo(layerZoning);
      }
    });

    if (fitBounds) {
      var bounds = layerZoning.getBounds();
      if (bounds && bounds.isValid()) {
        map.invalidateSize();
        map.fitBounds(bounds, {
          maxZoom: 15,
          animate: false,
          padding: [20, 20]
        });
      }
    }
  };

  var stripes = new L.StripePattern({
    color: '#FF0000',
    angle: -45
  });
  stripes.addTo(map);

  $('#isochrone_date, #isodistance_date').datepicker({
    language: I18n.currentLocale(),
    autoclose: true,
    calendarWeeks: true,
    todayHighlight: true,
    format: I18n.t("all.datepicker"),
    zIndexOffset: 1000
  });
  $('#isochrone_size').timeEntry({
    show24Hours: true,
    spinnerImage: '',
    defaultTime: '00:00'
  });
  $('#isochrone_hour, #isodistance_hour').timeEntry({
    show24Hours: true,
    spinnerImage: ''
  });

  $('#isochrone').click(function() {
    var vehicle_usage_id = $('#isochrone_vehicle_usage_id').val();
    var size = $('#isochrone_size').val().split(':');
    size = parseInt(size[0]) * 3600 + parseInt(size[1]) * 60;
    var departure = $('#isochrone_date').val() ? $('#isochrone_date').datepicker('getDate') : new Date();
    var hour = $('#isochrone_hour').val();
    if (hour) hour = hour.match(/^([0-9]{2}):([0-9]{2})$/);
    if (hour && hour[1] && hour[2])
      departure.setHours(hour[1], hour[2]);

    $('#isochrone-modal').modal('hide');
    $('#isochrone-progress-modal').modal({
      backdrop: 'static',
      keyboard: true
    });

    $.ajax({
      type: 'PATCH',
      url: '/api/0.1/zonings/isochrone.json',
      data: {
        vehicle_usage_id: vehicle_usage_id,
        size: size,
        lat: $('#isochrone_lat').val(),
        lng: $('#isochrone_lng').val(),
        departure: departure.toLocalISOString()
      },
      beforeSend: beforeSendWaiting,
      success: function(data) {
        fitBounds = true;
        displayZoning(data);
        map.closePopup();
      },
      complete: function() {
        completeAjaxMap();
        $('#isochrone-progress-modal').modal('hide');
      },
      error: stickyError
    });
  });

  $('#isodistance').click(function() {
    var vehicle_usage_id = $('#isodistance_vehicle_usage_id').val();
    var size = $('#isodistance_size').val() * 1000;
    var departure = $('#isodistance_date').val() ? $('#isodistance_date').datepicker('getDate') : new Date();
    var hour = $('#isodistance_hour').val();
    if (hour) hour = hour.match(/^([0-9]{2}):([0-9]{2})$/);
    if (hour && hour[1] && hour[2])
      departure.setHours(hour[1], hour[2]);

    $('#isodistance-modal').modal('hide');
    $('#isodistance-progress-modal').modal({
      backdrop: 'static',
      keyboard: true
    });

    $.ajax({
      type: 'PATCH',
      url: '/api/0.1/zonings/isodistance.json',
      data: {
        vehicle_usage_id: vehicle_usage_id,
        size: size,
        lat: $('#isodistance_lat').val(),
        lng: $('#isodistance_lng').val(),
        departure: departure.toLocalISOString()
      },
      beforeSend: beforeSendWaiting,
      success: function(data) {
        fitBounds = true;
        displayZoning(data);
        map.closePopup();
      },
      complete: function() {
        completeAjaxMap();
        $('#isodistance-progress-modal').modal('hide');
      },
      error: ajaxError
    });
  });
};

Paloma.controller('RoutesByVehicles', {
  show: function() {
    routesByVehicleShow(this.params);
  }
});
