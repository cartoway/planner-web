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
import { RoutesLayer } from '../../assets/javascripts/routes_layers';
import { selectTag } from '../../assets/javascripts/tags';
import {
  beforeSendWaiting,
  completeAjaxMap,
  ajaxError,
  completeWaiting,
  fake_select2,
  mustache_i18n,
  progressDialog
} from '../../assets/javascripts/ajax';
import {
  templateTag,
  bootstrap_dialog,
  continuousListLoading,
  mapInitialize,
  initializeMapHash,
  selectFormatOption,
  selectGlobalActions,
  templateSelectionColor,
  templateResultColor,
  updateSelectionCount,
  dropdownAutoDirection,
  modal_options,
  camelToSnake
} from '../../assets/javascripts/scaffolds';

$(function() {
  $('[data-toggle="tooltip"]').tooltip();
});

const getPlanningsId = function() {
  return $.makeArray($('#plannings').find('input[type=checkbox]:checked').map(function(index, id) { return $(id).val(); }));
};

const iCalendarExport = function(planningId) {
  var url = $('#ical_export').attr('href'), ids;
  // Initialize data only for index
  $('#btn-export').click(function(e) {
    ids = getPlanningsId();
    if (ids.length === 0) {
      warning(I18n.t('plannings.index.export.none_planning'));
      e.preventDefault();
    }
    $('#ical_export').attr('href', url + '&ids=' + ids.join(','));
  });

  $('.icalendar_email').click(function(e) {
    e.preventDefault();
    var ajaxParams = {email: true};
    if (!planningId) {
      ids = getPlanningsId();
      if (ids.length == 0) {
        warning(I18n.t('plannings.index.export.none_planning'));
        return;
      }
      else
        ajaxParams.ids = ids.join(',');
    }

    $.ajax({
      url: $(e.target).attr('href'),
      type: 'GET',
      data: ajaxParams,
      dataType: 'json'
    }).done(function() {
      notice(I18n.t('plannings.edit.export.icalendar.success'));
    }).fail(function() {
      stickyError(I18n.t('plannings.edit.export.icalendar.fail'));
    });
  });
};

const spreadsheetModalExport = function(columns, planningId, export_settings) {
  $('#planning-spreadsheet-modal').on('show.bs.modal', function() {
    if ($('[name=spreadsheet-route]').val())
      $('[name=spreadsheet-out-of-route]').parent().parent().hide();
    else
      $('[name=spreadsheet-out-of-route]').parent().parent().show();
  });
  $('#planning-spreadsheet-modal').on('hidden.bs.modal', function () {
    $('[name=spreadsheet-route]').val('');
  });

  if (export_settings && export_settings['stops']) {
    $.each($('.spreadsheet-stops'), function(i, cb) {
      $(cb).prop('checked', export_settings['stops'].indexOf($(cb).val()) >= 0);
    });
  }
  $('.columns-export-list').sortable({
    connectWith: '#spreadsheet-columns .ui-sortable'
  });
  var columnsExport = (export_settings && export_settings['export']) || [];
  var columnsSkip = (export_settings && export_settings['skips']) || [];
  if (columnsExport != []) {
    $.each(columns, function(i, c) {
      if (columnsExport.indexOf(c) < 0 && (!columnsSkip || columnsSkip.indexOf(c) < 0))
        columnsExport.push(c);
    });
  }
  var appendElement = function(parentSel, columnKey) {
    var displayName;
    var match = columnKey.match(new RegExp('^(.+)\\[(.*)\\]$'));
    var rematch = columnKey.match(/^([a-z]+(?:_[a-z]+)*)(\d+)$/);
    if (match) {
      var export_translation = 'plannings.export_file.' + match[1];
      displayName = I18n.t(export_translation) + '[' + match[2] + ']';
    }
    else if (rematch) {
      var export_translation = 'plannings.export_file.' + rematch[1];
      displayName = I18n.t(export_translation) + rematch[2];
    }
    else {
      var export_translation = 'plannings.export_file.' + columnKey;
      displayName = I18n.t(export_translation);
    }
    $(parentSel).append('<li data-value="' + columnKey + '">' + displayName + ' <a class="remove"><i class="fa fa-close fa-fw"></i></a></li>');
  };
  $.each(columnsExport, function(i, c) {
    if (columns.indexOf(c) >= 0)
      appendElement('#columns-export', c);
  });
  $.each(columnsSkip, function(i, c) {
    if (columns.indexOf(c) >= 0)
      appendElement('#columns-skip', c);
  });
  $('#columns-export').find('a.remove').click(function(evt) {
    var $elem = $(evt.currentTarget).closest('li');
    if ($elem.parent()[0].id === 'columns-export') {
      var nextFocus = $elem.next();
      $('a.remove', $elem).hide();
      $('#columns-skip').append($elem);
      if (nextFocus.length) $('a.remove', nextFocus).show();
    }
  });
  $('#columns-export').find('li').mouseenter(function(evt) {
    if ($(evt.currentTarget).closest('#columns-export').length > 0)
      $('a.remove', evt.currentTarget).show();
  }).mouseleave(function(evt) {
    $('a.remove', evt.currentTarget).hide();
  });
  if (export_settings && export_settings['format']) {
    $('[name=spreadsheet-format][value=' + export_settings['format'] + ']').prop('checked', true);
  }
  $('#btn-spreadsheet').click(function() {
    var planningsId = getPlanningsId();
    if (!planningId && planningsId.length == 0) {
      warning(I18n.t('plannings.index.export.none_planning'));
      return;
    }

    var spreadsheetStops = $('.spreadsheet-stops:checked').map(function(i, e) {
      return $(e).val();
    }).get().join('|');
    var spreadsheetColumnsExport = $('#columns-export').find('li').map(function(i, e) {
      return $(e).attr('data-value');
    }).get().join('|');
    var spreadsheetColumnsSkip = $('#columns-skip').find('li').map(function(i, e) {
      return $(e).attr('data-value');
    }).get().join('|');
    var spreadsheetFormat = $('[name=spreadsheet-format]:checked').val();
    var basePath = $('[name=spreadsheet-route]').val() ? ('/routes/' + $('[name=spreadsheet-route]').val()) : (planningId) ? '/plannings/' + planningId : '/plannings';

    window.location.href = basePath + '.' + spreadsheetFormat + '?stops=' + spreadsheetStops + '&columns=' + spreadsheetColumnsExport + "&ids=" + planningsId + '&skips=' + spreadsheetColumnsSkip;

    $('#planning-spreadsheet-modal').modal('toggle');
  });
  $('.export_spreadsheet').click(function() {
    $('#planning-spreadsheet-modal').modal({
      keyboard: true,
      show: true
    });
  });
};

const plannings_form = function() {
  $('#planning_date, #planning_begin_date, #planning_end_date, #isochrone_date, #isodistance_date').datepicker({
    language: I18n.currentLocale(),
    autoclose: true,
    calendarWeeks: true,
    todayHighlight: true,
    format: I18n.t("all.datepicker"),
    zIndexOffset: 1000
  });

  var formatNoMatches = I18n.t('web.select2.empty_result');
  $('select#planning_tag_ids').select2({
    theme: 'bootstrap',
    minimumResultsForSearch: -1,
    templateSelection: templateTag,
    templateResult: templateTag,
    formatNoMatches: function() {
      return formatNoMatches;
    },
    width: '100%',
    tags: true,
    closeOnSelect: false,
    createTag: function(params) {
      var term = $.trim(params.term);
      if (term === '') return null;
      return {
        id: term,
        newTag: true,
        text: term + ' ( + ' + I18n.t('web.select2.new') + ')'
      };
    }
  }).on('select2:open', function(e) {
    $(e.target).parent().find('.select2-search__field').attr('placeholder', I18n.t('web.select2.placeholder'));
  }).on('select2:close', function(e) {
    $(e.target).parent().find('.select2-search__field').attr('placeholder', '');
  }).on('select2:selecting', function(e) {
    selectTag(e);
  });
};

const plannings_new = function(params) {
  var onPlanningCreateModal = bootstrap_dialog({
    title: I18n.t('plannings.new.title'),
    icon: 'fa-calendar-check',
    message: SMT['modals/default_with_progress']({
      msg: I18n.t('plannings.new.dialog.new_planning')
    })
  });

  $('#new_planning').off('submit').on('submit', function() {
    onPlanningCreateModal.modal("show");
  });

  plannings_form();
  $("#planning_zoning_ids").select2({
    theme: 'bootstrap'
  });
};

export const plannings_edit = function(params) {
  plannings_form();

  var prefered_unit = (!params.prefered_unit ? "km" : params.prefered_unit),
    planning_id = params.planning_id,
    planning_ref = params.planning_ref,
    user_api_key = params.user_api_key,
    zoning_ids = params.zoning_ids,
    colorCodes = params.color_codes.slice(),
    vehicles_array = params.vehicles_array,
    vehicles_usages_map = params.vehicles_usages_map,
    withStopsInSidePanel = params.with_stops,
    url_click2call = params.url_click2call,
    layer_zoning,
    lastPopover,
    nbBackgroundTaskErrors = 0,
    backgroundTaskIntervalId,
    currentZoom = 17,
    needUpdateStopStatus = params.update_stop_status && withStopsInSidePanel,
    needUpdateTemperature = params.available_temperature,
    availableStopStatus = params.available_stop_status,
    outOfRouteId = params.routes_array.filter(function(route) {
      return !route.vehicle_usage_id;
    }).map(function(route) {
      return route.route_id;
    })[0],
    routes = $.map(params.routes_array, function(route) {
      if (route.vehicle_usage_id) {
        var vehicle_usage = {};
        $.each(vehicles_usages_map, function(i, v) {
          if (v.vehicle_usage_id == route.vehicle_usage_id) {
            vehicle_usage = v;
          }
        });
        route.name = (route.ref ? (route.ref + ' ') : '') + vehicle_usage.name;
        if (!route.color) {
          route.color = vehicle_usage.color;
        }
      }
      return route;
    }),
    vehicleIdsPosition = vehicles_array.filter(function(vehicle) {
      return vehicle.available_position;
    }).map(function(vehicle) {
      return vehicle.id;
    }),
    quantities = params.quantities,
    routes_devices = [],
    optimisationDuration = params.optimization_duration;
  colorCodes.unshift('');

  function getZonings() {
    return $("#planning_zoning_ids").val() || [];
  }

  function initUpdateRouteDeparture() {
    $(document).on('change', '.route-departure-field', function(e) {
      var route_id = $(this).data('route-id');
      var planning_id = $(this).data('planning-id');
      var departure = $(this).val();
      var routes = $(this).data('summary', 'routes');
      $.ajax({
        type: 'PUT',
        url: '/api/0.1/plannings/' + planning_id + '/routes/' + route_id + '.json',
        data: { departure: departure },
        beforeSend: function() {
          panelLoading(route_id);
          beforeSendWaiting();
        },
        success: function() {
          completeAjaxMap();
          refreshSidebarRoute(planning_id, route_id);
          routesLayer.refreshRoutes([route_id], routes);
        },
        error: ajaxError
      });
    });
  }
  initUpdateRouteDeparture();
  initRouteDepartureTimeEntry();

  var apply_zoning_modal = bootstrap_dialog({
    title: I18n.t('plannings.edit.dialog.zoning.title'),
    icon: 'fa-bars',
    message: SMT['modals/default_with_progress']({
      msg: I18n.t('plannings.edit.dialog.zoning.in_progress')
    })
  });

  $('.update-zonings-form').submit(function(e) {
    e.preventDefault();
    if (!confirm(I18n.t('plannings.edit.zoning_confirm'))) return;
    $.ajax({
      url: $(e.target).attr('action'),
      type: 'PATCH',
      data: {
        planning: { zoning_ids: getZonings() },
        with_stops: withStopsInSidePanel
      },
      dataType: 'json',
      beforeSend: function() {
        apply_zoning_modal.modal('show');
      },
      complete: function() {
        apply_zoning_modal.modal('hide');
      },
      success: function(data) {
        updatePlanning(data, {
          'partial': false
        });
        $('.update-zonings-form button[type=submit]').removeClass('btn-warning').addClass('btn-default').removeAttr('title');
        notice(I18n.t('plannings.edit.zonings.success'));
        zoning_ids = getZonings();
      },
      error: function() {
        stickyError(I18n.t('plannings.edit.zonings.fail'));
      }
    });
  });

  // Ensure touch compliance with chrome like browser
  L.controlTouchScreenCompliance();
  // sidebar has to be created before map
  var sidebar = L.control.sidebar('edit-planning', {
    position: 'left'
  });

  sidebar.open('planning-pane');

  var vehicleLayer;
  var vehicleMarkers = [];

  var displayVehicles = function(data) {
    $.each(data, function(i, pos) {
      if ($.isNumeric(pos.lat) && $.isNumeric(pos.lng)) {
        var route = routes.filter(function(route) {
          return (pos.vehicle_id in vehicles_usages_map) && (route.vehicle_usage_id === vehicles_usages_map[pos.vehicle_id].vehicle_usage_id);
        })[0];
        if (route) {
          var isMoving = pos.speed && (Date.parse(pos.time) > Date.now() - 600 * 1000);
          var direction_icon = pos.direction ? '<i class="fa fa-location-arrow fa-stack-1x vehicle-direction" style="transform: rotate(' + (parseInt(pos.direction) - 45) + 'deg);" />' : '';
          var iconContent = isMoving ?
            '<span class="fa-stack" data-route-id="' + route.route_id + '"><i class="fa fa-truck-field fa-stack-2x vehicle-icon pulse" style="color: ' + (route.color || vehicles_usages_map[pos.vehicle_id].color) + '"></i>' + direction_icon + '</span>' :
            '<i class="fa fa-truck-field fa-lg vehicle-icon" style="color: ' + (route.color || vehicles_usages_map[pos.vehicle_id].color) + '"></i>';
          vehicleLayer.removeLayer(vehicleMarkers[pos.vehicle_id]);

          var icon = new L.divIcon({
            html: iconContent,
            iconSize: new L.Point(24, 24),
            iconAnchor: new L.Point(12, 12),
            popupAnchor: new L.Point(0, -12),
            className: 'vehicle-position'
          });

          vehicleMarkers[pos.vehicle_id].setLatLng(new L.LatLng(pos.lat, pos.lng))
            .setIcon(icon)
            .addTo(vehicleLayer);

          var t = vehicleMarkers[pos.vehicle_id].getTooltip();
          if (t) {
            var content = $(t._content);
            content.find('#position-device-name').html(pos.device_name);
            content.find('#device-speed').html(prefered_unit === 'km' ? (pos.speed || 0) + ' km/h' : Math.ceil10(pos.speed / 1.609344) || 0 + ' mph');
            content.find("#speed-last").html(pos.time_formatted || (new Date(pos.time)).toLocaleString())
            vehicleMarkers[pos.vehicle_id].setTooltipContent('<div>' + content.html() + '</div>');
          }
        }
      }
    });
  };

  var requestVehiclePositionPending = false;
  var requestVehiclePosition = function() {
    if (!requestVehiclePositionPending) {
      $.ajax({
        type: 'GET',
        url: '/api/0.1/vehicles/current_position.json',
        data: {
          ids: vehicleIdsPosition
        },
        dataType: 'json',
        beforeSend: function() { requestVehiclePositionPending = true },
        complete: function() { requestVehiclePositionPending = false },
        success: function (data) {
          if (data && data.errors) {
            nbBackgroundTaskErrors++;
            if (nbBackgroundTaskErrors > 1) clearInterval(backgroundTaskIntervalId);
            $.each(data.errors, function(i, error) {
              stickyError(I18n.t('plannings.edit.current_position') + ' ' + error);
            });
          } else {
            displayVehicles(data);
          }
        },
        error: function() {
          nbBackgroundTaskErrors++;
          if (nbBackgroundTaskErrors > 1) clearInterval(backgroundTaskIntervalId);
        }
      });
    }
  };

  var updateStopsStatus = function(data) {
    var updateStopAndStoreStatusContent = function(content, el) {
      var klass = (el.store) ? 'store-row' : 'stop-row';
      var $elt = content.find('.toggle-status, .' + klass);
      var hadStatus = !($elt.css('display') == 'none');

      if (el.eta_formated) { content.find('.toggle-status-eta').show()} else { content.find('.toggle-status-eta').hide() }

      $elt = content.find('.' + klass);

      $.each($elt, function(i, elt) {
        $elt = $(elt);
        if (!el.status || el.status && !$elt.hasClass('stop-row-' + el.status_code)) {
          var match = $elt.attr("class").match(new RegExp('stop-row-[a-z]*'));
          if (match !== null) {
            $elt.removeClass(match.shift());
          }
          $elt.addClass(klass + (el.status_code ? ' stop-row-' + el.status_code : ''));
        }
      });
      var name = content.find('.title .name');
      if (name.attr('title')
        && (!el.status || name.attr('title').search(el.status) == -1)) {
        var title = name.attr('title').substr(0, hadStatus ? name.attr('title').lastIndexOf(' - ') : name.attr('title').length) + (el.status ? ' - ' + el.status : '')
        title += (el.eta_formated ? ' - ' + I18n.t('plannings.edit.popup.eta') + ' ' + el.eta_formated : '');
        name.attr({
          title: title
        });
      }
      name = content.find('.status');
      if (name.text() != el.status) name.text(el.status);
      name = content.find('.eta');
      if (name.text() != el.eta_formated) name.text(el.eta_formated);
      return content;
    };

    if (data) {
      var routeL, routeStops, marker, $item;

      $.each(data, function(i, route) {
        if (route.vehicle_usage_id) {
          var $route = $("[data-route-id='" + route.id + "']");
          var startStop = $route.find('[data-store-id]');

          // Adapter pattern for stores
          var startAdapter = { store: true, status: route.departure_status, status_code: route.departure_status_code, eta_formated: route.departure_eta_formated };
          var stopAdapter = { store: true, status: route.arrival_status, status_code: route.arrival_status_code, eta_formated: route.arrival_eta_formated };

          updateStopAndStoreStatusContent(startStop.first(), startAdapter);
          updateStopAndStoreStatusContent(startStop.last(), stopAdapter);

          $.each(route.stops, function(i, stop) {
            var sort = function(element) {
              return (element.properties.index == stop.index) ? element : void(0);
            };

            routeL = routesLayer.clustersByRoute[route.id];
            if (routeL) {
              routeStops = routeL.getLayers();
              marker = routeStops.filter(sort)[0];

              if (marker) {
                marker.properties.tomtom = stop;
              }
            }
            $.each($("[data-stop-id='" + stop.id + "']"), function(i, item) {
              // update list, active popup in map and active popover
              $item = $(item);
              updateStopAndStoreStatusContent($item, stop);
            });
          });
        }
      });
    }
  };

  var requestUpdateStopsStatusPending = false;
  var requestUpdateStopsStatus = function() {
    if (!requestUpdateStopsStatusPending) {
      $.ajax({
        type: 'PATCH',
        url: '/api/0.1/plannings/' + planning_id + '/update_stops_status.json',
        dataType: 'json',
        data: {
          details: true
        },
        beforeSend: function() { requestUpdateStopsStatusPending = true },
        complete: function() { requestUpdateStopsStatusPending = false },
        success: function(data) {
          if (data && data.errors) {
            nbBackgroundTaskErrors++;
            if (nbBackgroundTaskErrors > 1) clearInterval(backgroundTaskIntervalId);
            $.each(data.errors, function(i, error) {
              stickyError(I18n.t('plannings.edit.update_stops_status') + ' ' + error);
            });
          } else {
            updateStopsStatus(data);
          }
        },
        error: function() {
          nbBackgroundTaskErrors++;
          if (nbBackgroundTaskErrors > 1) clearInterval(backgroundTaskIntervalId);
        }
      });
    }
  };

  var requestUpdatedTemperaturePending = false;
  var requestUpdatedTemperature = function requestUpdatedTemperature(addToTooltip) {
    if (!requestUpdatedTemperaturePending) {
      $.ajax({
        type: 'GET',
        url: '/api/0.1/vehicles/temperature.json',
        data: {
          ids: vehicles_array.map(function(vehicle) { vehicle.id })
        },
        dataType: 'json',
        beforeSend: function() { requestUpdatedTemperaturePending = true },
        complete: function() { requestUpdatedTemperaturePending = false },
        success: onReceiveTemperature,
        error: function () {
          nbBackgroundTaskErrors++;
          if (nbBackgroundTaskErrors > 1) clearInterval(backgroundTaskIntervalId);
        }
      });
    }

    function onReceiveTemperature(vehicles) {
      var i18nTemp = I18n.t('plannings.edit.temperature_label');
      var i18nStatement = I18n.t('plannings.edit.last_temperature_statement_label');

      $.each(vehicles, function(i, v) {
        $.each(v.device_infos, function (i, device) {
          var temp = '#temperature-' + v.vehicle_id + '-' + device.device_id;
          var tempTxt = i18nTemp + ' ' + device.temperature + 'C°'
          $(temp).find('span').html(tempTxt);

          var dateStatement = '#last-date-' +v.vehicle_id + '-' + device.device_id;
          var dateStatementTxt = i18nStatement + ' ' + device.time_formatted
          $(dateStatement).find('span').html(dateStatementTxt)

          var t;
          if (addToTooltip
            && vehicleMarkers[v.vehicle_id]
            && (t = vehicleMarkers[v.vehicle_id].getTooltip())) {
            var content = $(t._content);
            content.find(temp + ' span').html(tempTxt);
            content.find(dateStatement + ' span').html(dateStatementTxt);
            vehicleMarkers[v.vehicle_id].setTooltipContent('<div>' + content.html() + '</div>')
          }
        });
      });
    }
  }

  var backgroundTask = function() {
    if (vehicleIdsPosition.length) {
      requestVehiclePosition();
    }
    if (needUpdateStopStatus) {
      requestUpdateStopsStatus();
    }
    if (needUpdateTemperature) {
      requestUpdatedTemperature(true);
    }
  };

  function initMarkers() {
    $.each(vehicleIdsPosition, function (i, id) {
      vehicleMarkers[id] = L.marker(new L.LatLng(0, 0));
    });

    backgroundTask();
  }

  if (vehicleIdsPosition.length || needUpdateStopStatus) {
    if (vehicleIdsPosition.length) {
      vehicleLayer = L.featureGroup();
      if (!params.overlay_layers) params.overlay_layers = {};
      params.overlay_layers[I18n.t("plannings.edit.vehicles")] = vehicleLayer;
    }
    initMarkers();
    backgroundTaskIntervalId = setInterval(backgroundTask, 60000);
    $(document).on('page:before-change', function() {
      clearInterval(backgroundTaskIntervalId);
    });
  }

  params.geocoder = true;

  var map = mapInitialize(params);
  var popupOptions = params.manage_planning;
  var routesLayer = new RoutesLayer(planning_id, {
    url_click2call: url_click2call,
    unit: prefered_unit,
    outOfRouteId: outOfRouteId,
    routes: routes,
    colorsByRoute: params.colors_by_route,
    appBaseUrl: params.apiWeb ? '/api-web/0.1/' : '/',
    popupOptions: popupOptions,
    disableClusters: params.disable_clusters
  }).on('clickStop', function(stop) {
    enlightenStop({index: stop.index, routeId: stop.routeId});
  }).addTo(map);

  if (vehicleLayer) map.addLayer(vehicleLayer);

  L.control.attribution({
    prefix: false,
    position: 'bottomleft'
  }).addTo(map);
  L.control.scale({
    imperial: false
  }).addTo(map);

  L.disableClustersControl(map, routesLayer);
  L.disableRoutePolylinesControl(map, routesLayer);

  var fitBounds = initializeMapHash(map);

  sidebar.addTo(map);

  $('#data_routes_dropdown').find('li a').click(function() {
    if (routes.length == 0) return;

    var selection = $(this).parent('li').data('selection');

    $('.route-data').each(function(index, element) {
      if (selection == 'all') {
        $(element).show();
      } else if (selection == 'none') {
        $(element).hide();
      } else if (selection == 'simple') {
        $(element).show();
      }
    });

    $('.route-data-advanced').each(function(index, element) {
      if (selection == 'all') {
        $(element).show();
      } else if (selection == 'none') {
        $(element).hide();
      } else if (selection == 'simple') {
        $(element).hide();
      }
    });
  });

  $('#lock_routes_dropdown, #toggle_routes_dropdown').find('li a').click(function() {
    if (routes.length == 0) return;

    var action = $(this).parent('li').parent('ul').attr('id') == 'lock_routes_dropdown' ? 'lock' : 'toggle';
    var selection = $(this).parent('li').data('selection');

    var successLock = function(data) {
      $.each(data, function(index, route) {
        var element = $("[data-route-id='" + route.id + "']");
        if (route.locked) {
          element.find(".lock").removeClass("btn-default").addClass("btn-warning");
          element.find('.lock i').removeClass('fa-unlock').addClass('fa-lock');
        } else {
          element.find(".lock").removeClass("btn-warning").addClass("btn-default");
          element.find('.lock i').removeClass('fa-lock').addClass('fa-unlock');
        }
      });
      checkLockAndActive();
    };
    var successToggle = function(data) {
      if (selection == 'all' || selection == 'reverse') {
        routesLayer.showAllRoutes();
      } else if (selection == 'none') {
        routesLayer.hideAllRoutes();
      }
      $.each(data, function(index, route) {
        var element = $("[data-route-id='" + route.id + "']");
        if (route.hidden) {
          element.find("ul.stops").hide();
          element.find('.toggle i').removeClass('fa-eye').addClass('fa-eye-slash');
          element.find('.center_view').prop('disabled', true);
          if (element.hasClass('out_route')) { $('#div_out_list_next_link').hide(); }
        } else {
          element.find("ul.stops").show();
          element.find('.toggle i').removeClass('fa-eye-slash').addClass('fa-eye');
          element.find('.center_view').removeAttr('disabled');
          if (element.hasClass('out_route')) { $('#div_out_list_next_link').show(); }
        }
      });
    };

    $.ajax({
      url: '/api/0.1/plannings/' + planning_id + '/update_routes',
      type: 'PATCH',
      data: {
        selection: selection,
        action: action,
        route_ids: $('[data-route-id]').map(function() {
          return $(this).data('route-id');
        }).get()
      },
      dataType: 'json',
      beforeSend: beforeSendWaiting,
      complete: completeAjaxMap,
      error: ajaxError,
      success: action == 'lock' ? successLock : successToggle
    });

  });

  // Used to highlight the current stop (or route if over 1t points) in sidebar routes
  var enlightenStop = function(stop) {
    var route = $(".routes [data-route-id='" + stop.routeId + "']");
    var target;

    if (stop.index) {
      target = $(".routes [data-route-id='" + stop.routeId + "'] [data-stop-index='" + stop.index + "']");
    } else {
      target = $("[data-stop-id='" + stop.id + "']");
    }

    if (target.length === 0) {
      target = route;
    } else {
      target.css("background", "orange");
      setTimeout(function() {
        target.css("background", "");
      }, 1500);
    }

    if (target.offset()) {
      var out_container = $(".out-content");
      if (route.hasClass('out_route') && (target.offset().top < out_container.offset().top || target.offset().top > out_container.offset().top + out_container.height())) {
        out_container.animate({
          scrollTop: target.offset().top - out_container.offset().top + out_container.scrollTop() - 40
        });
      } else if (!route.hasClass('out_route') && (target.offset().top < 0 || target.offset().top > $(".sidebar-content").height())) {
        $(".sidebar-content").animate({
          scrollTop: target.offset().top + $(".sidebar-content").scrollTop() - 100
        });
      }
    }
  };

  layer_zoning = (new L.FeatureGroup()).addTo(map);
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
      if (zone.vehicle_id) {
        this.on('click', function() {
          var route = $('select.vehicle_select[value="' + zone.vehicle_id + '"]').closest('.route');
          route.css('box-shadow', '#4D90FE 0px 0px 5px');
          setTimeout(function() {
            route.css('box-shadow', '');
          }, 1500);
          if (route.length) {
            $('.sidebar-content').animate({
              scrollTop: route.offset().top + $('.sidebar-content').scrollTop() - 100
            });
          }
        });
      }

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
            color: (zone.vehicle_id && vehicles_usages_map[zone.vehicle_id] ? vehicles_usages_map[zone.vehicle_id].color : '#707070'),
            fillColor: null,
            opacity: 0.5,
            weight: 2,
            dashArray: 'none',
            fillPattern: null
          });
        geom.addTo(layer_zoning);
      }
    });

    if (fitBounds) {
      var bounds = layer_zoning.getBounds();
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

  var templateSelectionZoning = function(zoning) {
    if (zoning.id)
      return $('<span><span class="zoning_name">' + zoning.text + '</span> <a href="/zonings/' + zoning.id + '/edit/planning/' + planning_id + '?back=true" title="' + I18n.t('plannings.edit.zoning_edit') + '"><i class="fa fa-pencil fa-fw"></i></a></span>');
  };

  $('#planning_zoning_ids').select2({
    theme: 'bootstrap',
    templateSelection: templateSelectionZoning
  });

  $('#planning_zoning_ids').change(function() {
    layer_zoning.clearLayers();
    var ids = $(this).val();
    $.ajax({
      type: 'PUT',
      data: JSON.stringify({
        zoning_ids: ids,
      }),
      contentType: 'application/json',
      url: '/api/0.1/plannings/' + planning_id + '.json',
      beforeSend: beforeSendWaiting,
      complete: completeAjaxMap,
      error: ajaxError
    });

    if (ids && ids.length > 0) {
      $.each(ids, function(i, id) {
        $.ajax({
          type: 'GET',
          url: '/api/0.1/zonings/' + id + '.json',
          beforeSend: beforeSendWaiting,
          success: displayZoning,
          complete: completeAjaxMap,
          error: ajaxError
        });
      });
    }
  });

  var toggleModalWarning = (function() {
    var _modalWarning = $(".modal-optim-warning");

    _modalWarning.find(".lock").on("click", function(e) {
      e.preventDefault();

      var unplannedRoute = $("ol.routes.out_routes");
      unplannedRoute.find("button.lock").trigger("click");

      toggleModalWarning();
    });

    return function toggleModalWarning() {
      var unplannedRoute = $("ol.routes.out_routes");
      var isLocked = unplannedRoute.find("button.lock > i").hasClass("fa-lock");
      var keepVisit = $('[name=sticky_vehicle]:checked').val() === 'true';

      !isLocked && keepVisit && (unplannedRoute.find("li[data-stop-id]").length || unplannedRoute.find(".load-stops").length)? _modalWarning.show() : _modalWarning.hide();
    };
  })();

  var optimizationTimer = (function() {
    var _routesLength,
      minTxt,
      maxTxt;

    var displayOptimDuration = function displayOptimDuration(error) {
      var _getOptimDuration = function _getOptimDuration() {
        return {
          min: _routesLength ? optimisationDuration.min * _routesLength : optimisationDuration.min,
          max: _routesLength ? optimisationDuration.max * _routesLength : optimisationDuration.max
        };
      };

      if (error) {
        return $(".optim-duration").hide();
      }
      var duration = _getOptimDuration();

      minTxt = _setText(duration.min, I18n.t('plannings.edit.dialog.optimization.optimize_min'));
      maxTxt = _setText(duration.max, I18n.t('plannings.edit.dialog.optimization.optimize_max'));

      $('.optim-duration #min-optim-duration').text(minTxt);
      $('.optim-duration #max-optim-duration').text(maxTxt);
    };

    var _setText = function setText(duration, text) {
      if (duration < 60) {
        return text + ' ' + I18n.t('plannings.edit.dialog.optimization.optimize_less') + ' 1 min.';
      }
      var seconds = Math.floor(duration % 60);
      return text + ' ' + Math.floor(duration / 60) + 'min. ' +  (seconds != 0 ? seconds + ' sec.' : '');
    };

    var setOptimDuration = function setOptimDuration(routesLength) {
      _routesLength = routesLength;
      return this;
    };

    var getNbRoute = function getNbRoute() {
      return _routesLength;
    };

    return {
      displayOptimDuration: displayOptimDuration,
      setOptimDuration: setOptimDuration,
      getNbRoute: getNbRoute
    };
  })();

  $('#optimize_all').click(function() {
    $('#optimization-route_id').val('').trigger('change');
    toggleModalWarning();
  });

  $('#optimization-route_id').change(function() {
    $(".modal-optim-warning").hide();
    var routeId = $(this).val();
    if (routeId.length === 0) {
      var routeLen = $('li[data-color]').find('.fa-unlock').length;
      optimizationTimer.setOptimDuration(routeLen);
      $('div#optimization-global').show();
      var sizeRoutes = 0;
      var activeSizeRoutes = 0;
      var allStopsActive = true;
      $.each($('li[data-route-id]:not(:last) [data-size-active]'), function() {
        var sizeRoute = $(this).attr('data-size');
        var activeSizeRoute = $(this).attr('data-size-active');
        if ($(this).closest('.route-tools').find('button.lock.btn-default').length > 0) {
          sizeRoutes += parseInt(sizeRoute);
          activeSizeRoutes += parseInt(activeSizeRoute);
        }
        if ($(this).attr('data-size-active') != sizeRoute)
          allStopsActive = false;
      });
      if (!sizeRoutes) {
        var g = $('#sticky_vehicle_false');
        if (!g.prop('disabled')) {
          g.prop('checked', true);
          $('div#optimization-global').hide();
        }
      }
      if ($('li.out_route button.lock.btn-default').length != 0) {
        sizeRoutes += $('li.out_route .stops li.waypoint').length;
        activeSizeRoutes += $('li.out_route .stops li.waypoint').length;
      }
      $('div#optimization-visit-counter').text(activeSizeRoutes + '/'+ sizeRoutes);

      $('div#optimization-active').css({display: allStopsActive ? 'none' : 'block'});
      var dimensions = $.map(vehicles_usages_map, function(vehicle) { return vehicle.router_dimension; })
        .filter(function(elt, idx, array) { return idx == array.indexOf(elt); });
      $('#router-dimension-value').html(dimensions.map(function(dim) { dim = 'plannings.edit.dialog.optimization.vehicles.' + dim; return I18n.t(dim); }).join(' / '));
    } else {
      $('div#optimization-global').hide();
      optimizationTimer.setOptimDuration();
      var sizeActive = $('li[data-route-id=' + routeId + '] [data-size-active]');
      $('div#optimization-active').css({display: (sizeActive.attr('data-size-active') == sizeActive.attr('data-size')) ? 'none' : 'block'});
      var route = routes.filter(function(route) {
        return route.route_id == routeId;
      })[0];
      var dimension;
      for (var vehicleId in vehicles_usages_map) {
        if (vehicles_usages_map[vehicleId].vehicle_usage_id == route.vehicle_usage_id)
          dimension = vehicles_usages_map[vehicleId].router_dimension;
      }
      dimension = 'plannings.edit.dialog.optimization.vehicles.' + dimension;
      $('#router-dimension-value').html(I18n.t(dimension));
    }

    optimizationTimer.displayOptimDuration();
    vehicleCostLate();
  });
  // FIXME: ortools is not able to support non null vehicle late multiplier for global optim
  var originalVehicleCostLate = $('#optimization-vehicle-late').find('label').text();
  var vehicleCostLate = function() {
    if (!$('#optimization-route_id').val() && $('[name=sticky_vehicle]:checked').val() == 'false') {
      if ($('#optimization-vehicle-late').find('label').text().trim() == I18n.t('all.value._yes'))
        $('#optimization-vehicle-late').find('label').text('-');
    }
    else
      $('#optimization-vehicle-late').find('label').text(originalVehicleCostLate);
  };
  vehicleCostLate();
  $('[name=sticky_vehicle]').change(function() {
    toggleModalWarning();
    vehicleCostLate();
  });

  function initRouteDepartureTimeEntry() {
    $('.route-departure-field').timeEntry('destroy').timeEntry({
      show24Hours: true,
      defaultTime: '00:00',
      spinnerImage: ''
    });
  }

  $('input[name="enable_optimization_soft_upper_bound"]').change(function() {
    $("#optimization-vehicle-max-upper-bound, #optimization-stop-max-upper-bound").toggleClass('d-none');
  });

  var panelLoading = function(route_id) {
    var route_panel = route_id ? $('.stops.sortable', 'li[data-route-id="' + route_id + '"]') : $('.stops.sortable');
    route_panel.sortable('disable')
               .closest('.panel')
               .addClass('spinner-container')
               .append('<div class="spinner-border"></div>');
  }

  var sortLoading = function(route, origin_route_id) {
    var route_id = route.attr('data-route-id');
    if (route_id != origin_route_id || !route.hasClass('out_route')) {
      panelLoading(route_id);
    }
    if (route_id != origin_route_id) {
      panelLoading(origin_route_id);
    }
  };

  var sortPlanning = function(event, ui) {
    var item = $(ui.item),
      index = 0,
      stop = item.closest("[data-stop-id]"),
      route = item.closest('[data-route-id]'),
      stops = $('.sortable li[data-stop-id]', route),
      route_id = route.attr('data-route-id'),
      stop_id = stop.attr("data-stop-id"),
      origin_route_id = stop.attr('data-origin-route-id');
    if (route.hasClass('out_route')) {
      index = -1;
      $('#div_out_list_next_link').hide();
    } else if (stops.length > 0) {
      while (stops[index].attributes['data-stop-id'].value != stop_id) {
        index++;
      }
      index++;
    }
    $.ajax({
      type: 'PATCH',
      url: '/plannings/' + planning_id + '/' + route_id + '/' + stop_id + '/move/' + (index) + '.json',
      beforeSend: function() {
        beforeSendWaiting();
        sortLoading(route, origin_route_id);
      },
      success: function(data, _status, xhr) {
        if (xhr.status === 204) return ;
        data.route_ids.forEach(function(route_id) {
          refreshSidebarRoute(planning_id, route_id);
        });
        routesLayer.refreshRoutes(data.route_ids, data.summary.routes);
      },
      complete: completeAjaxMap,
      error: function(request, status, error) {
        ajaxError(request, status, error);
        $(".route[data-route-id] .stops.sortable").sortable('cancel');
      }
    });
  };

  var externalCallbackUrl = function() {
    $(document).on('click', '.customer_external_callback_url', function(e) {
      const data = {};
      $.each($(this).data(), function(key, value) {
        data[camelToSnake(key)] = value;
      });
      $.ajax({
        url:  '/customers/' + $(this).data('customer-id') + '/external_callback',
        type: 'POST',
        data: data,
        beforeSend: beforeSendWaiting,
        complete: completeWaiting,
        success: function() {
          notice(I18n.t('plannings.edit.export.customer_external_callback_url.success'));
        },
        error: function() {
          stickyError(I18n.t('plannings.edit.export.customer_external_callback_url.fail'));
        }
      });
    });
  };

  var templateSelectionVehicles = function(vehicle) {
    if (vehicle.id) {
      var color = $('.color_select', $(vehicle.element).parent().parent()).val();
      if (color) {
        return $("<span/>").text(vehicles_usages_map[vehicle.id].name + ' - ' + vehicles_usages_map[vehicle.id].router_name);
      } else {
        return $("<span><span class='color_small' style='background:" + vehicles_usages_map[vehicle.id].color + "'></span>&nbsp;</span>").append($("<span/>").text(vehicles_usages_map[vehicle.id].name + ' - ' + vehicles_usages_map[vehicle.id].router_name));
      }
    }
  };

  var templateResultVehicles = function(vehicle) {
    if (vehicle.id) {
      return $("<span><span class='color_small' style='background:" + vehicles_usages_map[vehicle.id].color + "'></span>&nbsp;</span>").append($("<span/>").text(vehicles_usages_map[vehicle.id].name + ' - ' + vehicles_usages_map[vehicle.id].router_name));
    }
  };

  var switchVehicleModal = bootstrap_dialog({
    title: I18n.t('plannings.edit.dialog.vehicle.title'),
    icon: 'fa-bars',
    message: SMT['modals/default_with_progress']({
      msg: I18n.t('plannings.edit.dialog.vehicle.in_progress')
    })
  });

  var sendSMS = function() {
    $.ajax({
      type: 'GET',
      url: this.href,
      beforeSend: beforeSendWaiting,
      success: function(data) {
        stickyNotice(I18n.t('plannings.edit.send_sms_success', {c: data}));
      },
      complete: completeAjaxMap,
      error: ajaxError
    });
    $(this).closest(".dropdown-menu").prev().dropdown("toggle");
    return false;
  };

  var historize = function() {
    $.ajax({
      type: 'POST',
      url: this.href,
      beforeSend: beforeSendWaiting,
      success: function(data) {
        stickyNotice(I18n.t('plannings.edit.historize_success', {c: data}));
      },
      complete: completeAjaxMap,
      error: ajaxError
    });
    $(this).closest(".dropdown-menu").prev().dropdown("toggle");
    return false;
  };

  var initRouteSelector = function() {
    var previousSelection = [];
    $('#planning_route_ids').select2({
      dropdownParent: $('#planning_route_ids').parent(),
      closeOnSelect : false,
      allowClear: true,
      theme: 'bootstrap',
      placeholder: I18n.t('web.select2.search_placeholder'),
      templateSelection: selectFormatOption,
      templateResult: selectFormatOption,
    })
    .off('select2:close select2:open select2:select select2:unselect')
    .on('select2:open', function(e) {
      previousSelection = $(this).val() || [];
    }).on('select2:select', function(e) {
      selectGlobalActions($(this), e);
    }).on('select2:open', function(e) {
      setTimeout(function() {
        $('#route_selector .select2-results__option').each(function() {
          var optionValue = $(this).attr('id').split('-').pop();
          if (['clear', 'reverse', 'all'].includes(optionValue)) {
            $(this).addClass('global');
          }
        });
      }, 0);
    }).on('select2:select select2:unselect', function() {
      updateSelectionCount('#route_selector', '#planning_route_ids');
    })
      .on('select2:close', function(e) {
      var selectedIds = $(this).val();

      if (JSON.stringify(previousSelection)==JSON.stringify(selectedIds)) return;

      $.ajax({
        type: 'PATCH',
        url: '/plannings/' + planning_id + '/filter_routes.json',
        contentType: 'application/json',
        data: JSON.stringify({ route_ids: selectedIds }),
        dataType: 'json',
        beforeSend: beforeSendWaiting,
        success: function() {
          initPlanningDisplay(planning_id, { fitbound: true, firstTime: true })
        },
        complete: completeAjaxMap,
        error: ajaxError
      });
    });
  };

  // called first during plan initialization (context: plan), and several times after a route need to be refreshed (context: route)
  var initRoutes = function(context, data, options) {
    fake_select2($(".color_select", context), function(select) {
      select.select2({
        minimumResultsForSearch: -1,
        templateSelection: templateSelectionColor,
        templateResult: templateResultColor,
        formatNoMatches: I18n.t('web.select2.empty_result')
      }).select2("open");
      select.next('.select2-container--bootstrap').addClass('input-sm');
    });

    fake_select2($(".vehicle_select", context), function(select) {
      select.select2({
        minimumResultsForSearch: -1,
        data: vehicles_array,
        templateSelection: templateSelectionVehicles,
        templateResult: templateResultVehicles,
        formatNoMatches: I18n.t('web.select2.empty_result')
      }).select2("open");
      select.next('.select2-container--bootstrap').addClass('input-sm');
    });

    var $routes = context.hasClass('route') ? context : $(".route", context);

    var setTooltipColor = function setTooltipColor(vehicleUsageId, color) {
      var tooltip;
      if (vehicleMarkers.length
        && vehicleMarkers[vehicleUsageId]
        && (tooltip = vehicleMarkers[vehicleUsageId].getTooltip())) {
        var content = $(tooltip._content);
        content.children(":first").css({
          'border': '0.3em solid ' + color,
        });
        content.find('#vehicle-name').css('background-color', color)
        vehicleMarkers[vehicleUsageId].setTooltipContent('<div>' + content.html() + '</div>');
      }
    };

    // Following callbacks need to be set as many as route has changed
    $routes.off('change').on('change', "[name=route\\\[color\\\]]", function() {
      var id = $(this).closest('[data-route-id]').attr('data-route-id');
      var color = this.value;
      if (color)
        $('.color_small', $('.vehicle_select', $(this).parent()).next()).hide();
      else
        $('.color_small', $('.vehicle_select', $(this).parent()).next()).show();
      $.each(routes, function(i, route) {
        if (route.route_id == id) {
          route.color = color;
          if (!color) {
            for (var vehicle_id in vehicles_usages_map) {
              if (vehicles_usages_map[vehicle_id].vehicle_usage_id == route.vehicle_usage_id)
                color = vehicles_usages_map[vehicle_id].color;
            }
          }
          setTooltipColor(route.vehicle_usage_id, color);
        }
      });

      $.ajax({
        type: 'PUT',
        data: JSON.stringify({
          color: this.value
        }),
        contentType: 'application/json',
        url: '/api/0.1/plannings/' + planning_id + '/routes/' + id + '.json',
        success: function() {
          routesLayer.options.colorsByRoute[id] = color;
          routesLayer.refreshRoutes([id], routes);
        },
        error: ajaxError
      });
      $('li[data-route-id=' + id + '] li[data-store-id] > i.fa').css('color', color);
      $('li[data-route-id=' + id + '] li[data-stop-id] .number:not(.color_force):not(.inactive)').css('background', color);
      $('span[data-route-id=' + id + '] i.vehicle-icon').css('color', color);
    });

    $('.vehicle_select', context).off('change').change(function() {
      var $this = $(this);
      var initial_value = $this.data("initial-value");
      var route_id =  $this.closest('[data-route-id]').attr('data-route-id')
      if (initial_value !== $this.val()) {
        $.ajax({
          type: 'PATCH',
          data: JSON.stringify({
            route_id: route_id,
            vehicle_usage_id: vehicles_usages_map[$this.val()].vehicle_usage_id
          }),
          contentType: 'application/json',
          url: '/plannings/' + planning_id + '/switch.json',
          beforeSend: function() {
            beforeSendWaiting();
            panelLoading(route_id);
            switchVehicleModal.modal('show');
          },
          success: function(data) {
            displayPlanning(data, {
              partial: 'routes'
            });
          },
          complete: function() {
            completeAjaxMap();
            switchVehicleModal.modal('hide');
          },
          error: ajaxError
        });
      }
    });

    $('.export_spreadsheet', context).click(function() {
      $('[name=spreadsheet-route]').val($(this).closest('[data-route-id]').attr('data-route-id'));
      $('#planning-spreadsheet-modal').modal({
        keyboard: true,
        show: true
      });
    });

    $('.kmz_email a', context).click(function(e) {
      e.preventDefault();
      $.ajax({
        url: $(e.target).attr('href'),
        type: 'GET',
        beforeSend: beforeSendWaiting,
        complete: completeWaiting,
        success: function() {
          notice(I18n.t('plannings.edit.export.kmz_email.success'));
        },
        error: function() {
          stickyError(I18n.t('plannings.edit.export.kmz_email.fail'));
        }
      });
    });

    // Following callbacks need to be set only once
    if (!options || !options.skipCallbacks) {
      devicesObservePlanning.init(context, function() {
        if (availableStopStatus) {
          needUpdateStopStatus = true;
          requestUpdateStopsStatus();
        }
      });

      iCalendarExport(planning_id);

      $('.routes', context).sortable({
        disabled: true,
        items: 'li.route'
      });
      $routes
        .off("click", ".toggle")
        .on("click", ".toggle", function() {
          var id = $(this).closest("[data-route-id]").attr("data-route-id");
          var li = $("ul.stops, ol.stops", $(this).closest("li"));
          li.toggle();
          var hidden = !li.is(":visible");
          var i = $("i", this);
          var route_tools = i.closest('.route-tools');
          $.ajax({
            type: 'PUT',
            data: JSON.stringify({
              hidden: hidden,
              geojson: (id in routesLayer.clustersByRoute) ? 'false' : 'polyline'
            }),
            contentType: 'application/json',
            url: '/api/0.1/plannings/' + planning_id + '/routes/' + id + '.json',
            success: function(data) {
              if (hidden) {
                i.removeClass("fa-eye").addClass("fa-eye-slash");
                routesLayer.hideRoutes([id]);
                li.closest(".route-stops").find("#div_out_list_next_link").hide();
                route_tools.find('.center_view').prop('disabled', true);
              } else {
                i.removeClass("fa-eye-slash").addClass("fa-eye");
                routesLayer.showRoutes([id], JSON.parse(data.geojson));
                li.closest(".route-stops").find("#div_out_list_next_link").show();
                route_tools.find('.center_view').removeAttr('disabled');
              }
            },
            error: ajaxError
          });
        })
        .off("click", ".marker")
        .on("click", ".marker", function() {
          var stopIndex = $(this).closest("[data-stop-index]").attr("data-stop-index");
          if (stopIndex) {
            var routeId = $(this).closest("[data-route-id]").attr("data-route-id");
            routesLayer.focus({routeId: routeId, stopIndex: stopIndex});
          } else {
            var storeId = $(this).closest("[data-store-id]").attr("data-store-id");
            if (storeId) {
              routesLayer.focus({storeId: storeId});
            }
          }
          $(this).blur();
          return false;
        })
        .off("click", ".center_view")
        .on("click", ".center_view", function() {
          var route_id = $(this).closest("[data-route-id]").attr("data-route-id");
          if (route_id) {
            routesLayer.focus({routeId: route_id});
          }
        })
        .off("click", ".optimize")
        .on('click', '.optimize', function() {
          $('#optimization-route_id').val($(this).closest('[data-route-id]').attr('data-route-id')).trigger('change');
        })
        .off("click", ".send_sms")
        .on('click', '.send_sms', sendSMS)
        .off("click", ".active_all, .active_reverse, .active_none, .active_status, .reverse_order")
        .on("click", ".active_all, .active_reverse, .active_none, .active_status, .reverse_order", function() {
          var route_id = $(this).closest('[data-route-id]').attr('data-route-id');
          if (!route_id) return false;

          $.ajax({
            type: 'PATCH',
            url: this.href,
            beforeSend: function() {
              panelLoading(route_id);
              beforeSendWaiting();
            },
            success: function() {
              updateSuccess(locals.summary, map, locals.updated_routes, {skipCallbacks: true});
              routesLayer.refreshRoutes(locals.updated_routes.map(route => route.route_id), locals.summary.routes);
            },
            complete: completeAjaxMap,
            error: ajaxError
          });
          $(this).closest(".dropdown-menu").prev().dropdown("toggle");
          return false;
        })
        .off("change", "[name=route\\\[ref\\\]]")
        .on("change", "[name=route\\\[ref\\\]]", function() {
          var id = $(this).closest("[data-route-id]").attr("data-route-id");
          var ref = this.value;
          $.ajax({
            type: 'PUT',
            data: JSON.stringify({
              ref: ref
            }),
            contentType: 'application/json',
            url: '/api/0.1/plannings/' + planning_id + '/routes/' + id + '.json',
            success: function (response) {
              setTooltipRef(response.vehicle_usage_id, ref);
            },
            error: ajaxError
          });
        })
        .off('click', '.lock')
        .on('click', '.lock', function() {
          var id = $(this).closest("[data-route-id]").attr("data-route-id");
          var i = $("i", this);
          i.toggleClass("fa-lock");
          i.toggleClass("fa-unlock");
          $(this).toggleClass("btn-default");
          $(this).toggleClass("btn-warning");
          var locked = i.hasClass("fa-lock");
          checkLockAndActive();
          $.ajax({
            type: 'PUT',
            data: JSON.stringify({
              locked: locked
            }),
            contentType: 'application/json',
            url: '/api/0.1/plannings/' + planning_id + '/routes/' + id + '.json',
            error: ajaxError
          });
        });

      var setTooltipRef = function setTooltipRef(vehicleUsageId, ref) {
        var tooltip;
        if (vehicleMarkers.length
          && vehicleMarkers[vehicleUsageId]
          && (tooltip = vehicleMarkers[vehicleUsageId].getTooltip())) {
          var content = $(tooltip._content);
          var name = vehicles_usages_map[vehicleUsageId].name;
          content.find('#vehicle-name').html(ref + ' ' + name);
          vehicleMarkers[vehicleUsageId].setTooltipContent('<div>' + content.html() + '</div>');
        }
      };

      /** move_stops */
      $('#planning-move-stops-modal').off().on('show.bs.modal', function(ev) {
        $('#planning-move-stops-modal .modal-body').html(
          '<div class="spinner"><i class="fa fa-spin fa-2x fa-spinner"></i></div>'
        ).unbind();
        var routeId = ev.relatedTarget.attributes['data-route-id'].value;

        var _routes = routes.filter(function(obj) {
          return obj.route_id != routeId;
        }).map(function(obj) {
          if (obj.name === "undefined") {
            obj.name = I18n.t('plannings.edit.out_of_route');
            obj.color = '#fff';
          }
          return obj;
        });

        var templateRoute = function(route) {
          if (route.id) {
            var obj = $.grep(_routes, function(obj){return obj.route_id === parseInt(route.id);})[0]
            return $("<span><span class='color_small' style='background: " + obj.color + "'></span>&nbsp;</span>")
              .append($("<span/>").text(route.text));
          }
        };

        $.ajax({
          type: 'GET',
          contentType: 'application/json',
          url: '/plannings/' + params.planning_id + '.json',
          data: { "route_ids": routeId },
          error: ajaxError,
          success: function(data) {
            var stops = data.routes[0].stops;
            var obj = {
              color: data.routes[0].color,
              count: data.routes[0].size,
              i18n: mustache_i18n,
              quantities: data.routes[0].quantities,
              routes: _routes,
              stops: stops,
              vehicle: data.routes[0].vehicle_id ? true : false
            };

            $('#planning-move-stops-modal .modal-body').html(SMT['stops/move'](obj));
            $('#move-stops-toggle').toggleSelect();
            $('[type="checkbox"][data-toggle="disable-multiple-actions"]').toggleMultipleActions();

            $('#move-route-id').select2({ templateSelection: templateRoute, templateResult: templateRoute, minimumResultsForSearch: -1 });
            $('#planning-move-stops-modal input[data-change="filter"]').filterTable()
              .on('table.filtered', function() { calculateQuantities(stops); });
            $('#planning-move-stops-modal .move-stops-stop-id').change(function() { calculateQuantities(stops); });
            $('#move-route-id').change(function(obj) {
              var vehicleUsageId = obj.target.selectedOptions[0].attributes['data-vehicle-usage-id'].value;
              fillQuantities(stops, vehicleUsageId);
            });
            fillQuantities(stops);
            $('.overflow-500').css('max-height', ($(document).height() - 440) + 'px');
          }
        });
      });

      var calculateQuantities = function(stops, vehicleUsageId) {
        vehicleUsageId = vehicleUsageId ? vehicleUsageId : $('#move-route-id').find(":selected").attr('data-vehicle-usage-id');
        var $moveStopQuantities = $('#move-stop-quantities');
        var $moveStopGlobalQuantities = $('#move-stop-global-quantities');
        var vehicleQuantities = getVehicleQuantities(vehicleUsageId);
        var stopsToMove = getAvailableStopsToMoveFrom(stops);
        var globalStops = vehicleQuantities ? stopsToMove.concat(vehicleQuantities) : stopsToMove;

        $moveStopQuantities.calculateQuantities(stopsToMove, params.quantities);
        $moveStopGlobalQuantities.calculateQuantities(globalStops, params.quantities);
      };

      var fillQuantities = function(stops, vehicleUsageId) {
        vehicleUsageId = vehicleUsageId ? vehicleUsageId : $('#move-route-id').find(":selected").attr('data-vehicle-usage-id');
        var $moveStopQuantities = $('#move-stop-quantities');
        var $moveStopGlobalQuantities = $('#move-stop-global-quantities');
        var vehicleCapacities = getVehicleCapacities(vehicleUsageId);
        var vehicleQuantities = getVehicleQuantities(vehicleUsageId);
        var stopsToMove = getAvailableStopsToMoveFrom(stops);
        var globalStops = vehicleQuantities ? stopsToMove.concat(vehicleQuantities) : stopsToMove;

        $moveStopGlobalQuantities.empty().fillQuantities({
          vehicleCapacities: vehicleCapacities,
          stops: globalStops,
          controllerParamsQuantities: params.quantities,
          withCapacity: true,
        });
        $moveStopQuantities.empty().fillQuantities({
          vehicleCapacities: vehicleCapacities,
          stops: stopsToMove,
          controllerParamsQuantities: params.quantities,
          withDuration: true
        });
      };

      var getAvailableStopsToMoveFrom = function(stops) {
        var availableStopsToMove = $('#planning-move-stops-modal .move-stops-stop-id:checked:visible');
        var selectedStops = [];
        for (var index = 0; index < availableStopsToMove.length; index++) {
          var element = availableStopsToMove[index];
          selectedStops.push(stops.filter(function(stop) { return stop.stop_id === parseInt(element.value); })[0]);
        }
        return selectedStops;
      };

      var getVehicleQuantities = function(vehicleUsageId) {
        var quantities;
        try {
          $.each(Object.keys(vehicles_usages_map), function(i, index) {
            if (vehicles_usages_map[index].vehicle_usage_id === parseInt(vehicleUsageId)) {
              quantities = vehicles_usages_map[index].vehicle_quantities;
              throw {};
            }
          });
        } catch (exc) {
          return {quantities: quantities};
        }
      };

      var getVehicleCapacities = function(vehicleUsageId) {
        return Object.keys(vehicles_usages_map).map(function(index) {
          if (vehicles_usages_map[index].vehicle_usage_id === parseInt(vehicleUsageId)) {
            var capacities = vehicles_usages_map[index].default_capacities;
            return Object.keys(capacities).map(function(id) {
              var quantity = $.grep(quantities, function(obj){return obj.id === parseInt(id);})[0]
              if (quantity) return {id: id, capacity: capacities[id], label: quantity.label, unitIcon: quantity.unit_icon};
            }).filter(function(element) { return element; });
          }
        }).filter(function(element) { return element; })[0];
      };

      $('#planning-move-stops-modal').off('hidden.bs.modal').on('hidden.bs.modal', function() {
        $('#planning-move-stops-modal').attr('data-route-id', null);
      });

      $("#move-stops-modal").off('click').on('click', function() {
        var stopIds = $("#planning-move-stops-modal")
          .find('form input[name="stop_ids"]:checked:visible')
          .map(function() { return $(this).val(); })
          .toArray();
        $.ajax({
          type: 'PATCH',
          url: '/plannings/' + params.planning_id + '/' + $("#move-route-id").val() + '/move.json',
          data: {
            'stop_ids': stopIds,
            'index': $('#move-index').val()
          },
          beforeSend: function() {
            beforeSendWaiting();
            $('#planning-move-stops-modal').modal('hide');
          },
          error: ajaxError,
          success: function(data, _status, xhr) {
            if (xhr.status === 204) return;

            data.route_ids.forEach(function(route_id) {
              refreshSidebarRoute(params.planning_id, route_id);
            });
            routesLayer.refreshRoutes(data.route_ids, data.summary.routes);
          },
          complete: completeAjaxMap
        });
      });
      /** End move_stops */

      $('.load-stops', context).click(function(event) {
        var routeId = $(event.target).closest('[data-route-id]').attr('data-route-id');
        panelLoading(routeId);
        refreshSidebarRoute(params.planning_id, routeId);
      });
    }
  };

  var checkLockAndActive = function() {
    var maxUnlockedStops = 0;
    $('.route[data-route-id]').each(function() {
      var isRouteLocked = $(this).find('.lock i').hasClass('fa-lock');
      var stopCount = $(this).find('[data-size-active]').data('size-active');

      if (!isRouteLocked && stopCount)
        maxUnlockedStops = Math.max(maxUnlockedStops, stopCount);
      if (!isRouteLocked && stopCount > 1) {
        $(this).find('button.optimize').prop('disabled', false);
      }
      else
        $(this).find('button.optimize').prop('disabled', true);
    });

    if (!maxUnlockedStops) {
      $('#planning_zoning_button').attr('disabled', 'disabled');
    } else {
      $('#planning_zoning_button').removeAttr('disabled');
    }
    if (maxUnlockedStops < 2) {
      $('#global_tools').find('button.optimize').attr('disabled', 'disabled');
    } else {
      $('#global_tools').find('button.optimize').removeAttr('disabled');
    }
  };

  var buildUrl = function(url, hash) {
    $.each(hash, function(k) { url = url.replace('\{' + k.toUpperCase() + '\}', hash[k]); });
    return url;
  };

  var api_route_calendar_path = function(route) {
    return '/api/0.1/plannings/' + (planning_ref ? 'ref:' + encodeURIComponent(planning_ref) : planning_id) +
      '/routes/' + (route.ref ? 'ref:' + encodeURIComponent(route.ref) : route.route_id) + '.ics';
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

  var displayOptimModal = function(locals, options) {
    if (locals.optimizer) {
      optimizationTimer
        .setOptimDuration(locals.optimizer.dispatch_params_delayed_job.nb_route)
        .displayOptimDuration(locals.optimizer.dispatch_params_delayed_job.error);
    }

    if (!progressDialog(locals.optimizer, dialog_optimizer, '/plannings/' + planning_id + '.json' + (options.firstTime ? '?with_stops=' + withStopsInSidePanel : ''), displayPlanning, options)) {
      return;
    }
  }

  // Depending 'options.partial' this function is called for initialization or for pieces of planning
  var displayPlanning = function(data, options) {

    // Display optimization duration in modal on page reload
    if (data.optimizer) {
      var len = data.optimizer.dispatch_params_delayed_job.routes ?
        data.optimizer.dispatch_params_delayed_job.routes.length : data.optimizer.dispatch_params_delayed_job.nb_route;
      optimizationTimer.setOptimDuration(len).displayOptimDuration(data.optimizer.error);
    }

    if (!progressDialog(data.optimizer, dialog_optimizer, '/plannings/' + planning_id + '.json' + (options.firstTime ? '?with_stops=' + withStopsInSidePanel : ''), displayPlanning, options)) {
      return;
    }

    var routeDevices = function(route) {
      if (route) {
        return {
          vehicle_name: route.name,
          vehicle_id: route.vehicle_id,
          devices: route.devices,
          color: route.color
        }
      }
    }

    function setRouteVariables(i, route) {
      route.calendar_url = api_route_calendar_path(route);
      route.calendar_url_api_key = api_route_calendar_path(route) + '?api_key=' + user_api_key;

      if (route.vehicle_id) {
        route.vehicle = vehicles_usages_map[route.vehicle_id];
        route.path = '/vehicle_usages/' + route.vehicle_usage_id + '/edit?back=true';
      }
    }

    const updateRouteModel = function(i, route) {
      let vehicle_usage = {};
      $.each(vehicles_usages_map, function(i, v) {
        if (v.vehicle_usage_id == route.vehicle_usage_id) vehicle_usage = v;
      });
      $.each(routes, function(i, rv) {
        if (rv.route_id == route.route_id) {
          routes[i] = {
            route_id: route.route_id,
            color: route.color || vehicle_usage.color,
            vehicle_usage_id: route.vehicle_usage_id,
            ref: route.ref,
            name: route.name,
            outdated: route.outdated,
            devices: route.devices || params.devices
          };
        }
      });
      updateColorsForRoutesAndStops(i, route);
    }

    data.i18n = mustache_i18n;
    data.planning_id = data.id;

    var displayed_routes = data.routes.filter(function(route) {
      return $(`.route[data-route-id="${route.route_id}"]`).length > 0;
    });

    $.each(displayed_routes, function(i, route) {
      setRouteVariables(i, route);
      // update global routes
      updateRouteModel(i, route);
      var inArray = $.grep(routes_devices, function(d) {
        return d.vehicle_id == route.vehicle_id
      }).length;
      if (route.devices && !inArray) {
        routes_devices.push(routeDevices(route));
      }
    });

    var refreshBtn = $('button#refresh');
    if (refreshBtn.length) {
      var outdated = true;
      for (var id in routes) {
        if (routes[id].outdated) {
          outdated = false;
          break;
        }
      }
      if (outdated) refreshBtn.hide();
    }

    $.each(routes_devices, function(i, d) {
      if (vehicleMarkers[d.vehicle_id]) {
        vehicleMarkers[d.vehicle_id].bindTooltip(SMT['devices/tooltip']({
          vehicle_id: d.vehicle_id,
          name: d.vehicle_name,
          devices: d.devices,
          color: d.color,
          i18n: data.i18n
        }), { className: 'marker-tooltip', opacity: 1 });
      }
    });
    backgroundTask();

    // 1st case: the whole planning needs to be initialized and displayed
    if (typeof options !== 'object' || !options.partial) {
      data.ref = null; // here to prevent mustache template to get the value
      $.extend(data, params.manage_planning);
      data.callback_button = params.callback_button;
      initPlanningDisplay(planning_id, $.extend(options, {fitBounds: fitBounds}));
    }
    // 2nd case: several routes needs to be displayed (header and map), for instance by switching vehicles
    else if (typeof options === 'object' && options.partial === 'routes') {
      $.each(displayed_routes, function(i, route) {
        var vehicle_usage = {};
        $.each(vehicles_usages_map, function(i, v) {
          if (v.vehicle_usage_id == route.vehicle_usage_id) vehicle_usage = v;
        });
        routesLayer.options.colorsByRoute[route.route_id] = route.color || vehicle_usage.color;
      });

      var routeIds = [];
      $.each(displayed_routes, function(i, route) {
        routeIds.push(route.route_id);
        route.i18n = mustache_i18n;
        route.planning_id = data.id;
        route.routes = routes;
        var associated_route = $.grep(routes_devices, function(r) { return route.vehicle_id == r.vehicle_id })
        if (associated_route.length)
          route.devices = associated_route[0].devices;

        $.extend(route, params.manage_planning);
        refreshSidebarRoute(route.planning_id, route.route_id, {skipCallbacks: true});
        const $routePanel = $(`.route[data-route-id="${route.route_id}"]`);
        initRoutes($routePanel, data, $.merge({skipCallbacks: true}, options));

        var regExp = new RegExp('/plannings/' + route.planning_id + '/' + route.route_id + '/[0-9]+/move.json');
        // popups are not selected follow
        $.each($('.send_to_route'), function(j, link) {
          var $link = $(link);
          if ($link.attr('href').match(regExp) != null)
            $link.html('<div class="color_small" style="background:' + (route.color || route.vehicle.color) + '"></div> ' + route.vehicle.name);
        });
        $.each($('li[data-stop-id]'), function(i, stop) {
          var popupContent = $(stop).data()['bs.popover'] && $($(stop).data()['bs.popover'].options.content);
          if (popupContent) {
            $.each($('.send_to_route', popupContent), function(j, link) {
              var $link = $(link);
              if ($link.attr('href').match(regExp) != null)
                $link.html('<div class="color_small" style="background:' + (route.color || route.vehicle.color) + '"></div> ' + route.vehicle.name);
            });
            $(stop).data()['bs.popover'].options.content = popupContent;
          }
        });
      });

      routesLayer.refreshRoutes(routeIds, routes);
    }
    // 3rd case: only stops needs to be refreshed, for instance after moving stop
    else if (typeof options === 'object' && options.partial === 'stops') {
      $.each(displayed_routes, function(i, route) {
        route.i18n = mustache_i18n;
        route.planning_id = data.id;
        route.routes = routes;

        $.extend(route, params.manage_planning);

        refreshSidebarRoute(planning_id, route.route_id, {skipCallbacks: true});
        const $routePanel = $(`li.route[data-route-id="${route.route_id}"]`);
        initRoutes($routePanel, data, $.merge({skipCallbacks: true}, options));
        if (!options || !options.skipMap) {
          routesLayer.refreshRoutes([route.route_id], routes)
        }
      });
    }
  };

  var refreshSidebarRoute = function(planning_id, route_id, options) {
    $.ajax({
      type: 'GET',
      url: '/plannings/' + planning_id + '/' + route_id + '/refresh.js?with_stops=' + true,
      beforeSend: beforeSendWaiting,
      error: ajaxError,
      success: function() {
        updateSuccess(locals.summary, map, [locals.route], options);
        initRouteSelector();
        updateSelectionCount('#route_selector', '#planning_route_ids');
        if (!locals.route.vehicle_usage_id) {
          continuousListLoading('#out_route_scroll', '#out_list_next_link', '#out_list_loading', 100);
        }
      },
      complete: completeAjaxMap
    });
  }

  var updateDataHeader = function(planning_id) {
    $.ajax({
      type: 'GET',
      url: '/plannings/' + planning_id + '/data_header.js',
      beforeSend: beforeSendWaiting,
      error: ajaxError,
      complete: completeAjaxMap
    });
  }

  var updateSuccess = function(data, map, routes, options) {
    var sidebar = $('.sidebar');
    if (sidebar.hasClass('extended')) {
      if ($("#planning.routes").hasClass('ui-sortable')) {
        $(".routes").sortable('destroy');
      }
      sidebar.find('.toggle').prop('disabled', true);
      sidebar.find('.center_view').prop('disabled', true);
      $(".routes").sortable();
    }
    $("#planning").on("click", "#refresh", function() {
        $.ajax({
          type: 'GET',
          url: '/plannings/' + planning_id + '/refresh.json?with_stops=' + withStopsInSidePanel,
          beforeSend: function() {
            beforeSendWaiting();
            panelLoading();
          },
          success: displayPlanningFirstTime,
          complete: completeAjaxMap,
          error: ajaxError
        });
      });

    checkLockAndActive();
    var routesWithVehicle = data.routes.filter(function(route) { return route.vehicle_usage_id; });
    $.each(routes, function(i, route) {

      const $routePanel = $(`.route[data-route-id="${route.route_id}"]`);
      initRoutes($routePanel, data, options);

      var sortableUpdate = false;
      var $sortable_route = $(".route[data-route-id='" + route.route_id + "'] .stops.sortable");
      if ($sortable_route.hasClass('ui-sortable')) {
        $sortable_route.sortable('destroy');
      }
      $sortable_route.sortable({
        distance: 8,
        connectWith: ".sortable",
        containment: "#edit-planning",
        tolerance: "pointer",
        appendTo: '#planning',
        items: "> li",
        cancel: '.wait',
        helper: function(event, ui) {
          var $clone = $(ui).clone();
          $clone.wrap('<ol class="routes"><li class="route"><ul class="stops"></ol></li></ol>');
          return $clone.parent().parent().parent();
        },
        start: function() {
          sortableUpdate = false;
        },
        update: function() {
          sortableUpdate = true;
        },
        stop: function(event, ui) {
          if (sortableUpdate) {
            sortPlanning(event, ui);
          }
        }
      }).disableSelection();
      $(".route[data-route-id='" + route.route_id + "'] li[data-stop-id]")
        .mouseover(function() {
          if ($(window).width() >= 992) {
            $('.not-hover', this).css({
              display: 'none'
            });
          }
          $('.hover-tools', this).css({
            display: 'inline-block'
          });
        })
        .mouseout(function() {
          $('.hover-tools', this).css({
            display: 'none'
          });
          $('.not-hover', this).css({
            display: 'inline-block'
          });
        })
        .each(function() {
          var $this = $(this);
          var stops = $.grep(route.stops, function(e) { return e.stop_id === $this.data('stop-id'); });
          if (stops.length > 0) {
            var stopData = $.extend(stops[0], {
              number: $('.number', $this).text(),
              i18n: mustache_i18n,
              planning_id: data.planning_id,
              routes: routesWithVehicle,
              out_of_route_id: outOfRouteId,
              route_id: route.route_id,
              vehicle_name: route.vehicle_name,
              popover: true,
              manage_organize: true,
              manage_destination: true,
              manage_store: false
            });

            $this.popover({
              content: SMT['stops/show'](stopData),
              html: true,
              placement: 'auto',
              trigger: 'manual',
              viewport: {
                selector: '.sidebar-content',
                padding: 20
              }
            });

            $('.close-popover').click(function() {
              $(lastPopover).popover('hide');
            });
          }
        })
        .click(function() {
          // Stack the last element activated
          lastPopover = $(this);
          $("li[data-stop-id!='" + $(this).data('stop-id') + "']").popover('hide');
          $(this).popover($('.sidebar').hasClass('extended') ? 'toggle' : 'hide');
          $('.close-popover').click(function() {
            $(lastPopover).popover('hide');
          });
        });
    });

    updateDataHeader(data.planning_id);

    $(document).keyup(function(event) {
      if ($(".sidebar").hasClass('extended') && event.keyCode === 27 && typeof lastPopover !== 'undefined') {
        $(lastPopover).popover('hide');
      }
    });

    dropdownAutoDirection($('#planning').find('[data-toggle="dropdown"]'));

    map.closePopup();

    checkLockAndActive();

    var updateOptimButton = function(routes) {
      routes.forEach(function(route) {
        $("li[data-route-id=\"" + route.route_id + "\"]").find('.optimize').toggleClass('btn-success', !!route.optimized_at_formatted);
      });
    };

    updateOptimButton(routes);
    initRouteDepartureTimeEntry();

  }

  // Update only stops by default
  var updatePlanning = function(data, options) {
    displayPlanning(data, $.extend({
      partial: 'stops'
    }, options));
  };

  function automaticInsertStops(stop_ids, options) {
    $.ajax($.extend({
      url: '/plannings/' + planning_id + '/automatic_insert',
      type: 'PATCH',
      dataType: 'json',
      data: {
        stop_ids: stop_ids
      },
      beforeSend: beforeSendWaiting,
      complete: completeAjaxMap,
      error: ajaxError,
      success: updatePlanning
    }, options));
  }

  $(".main").on("click", ".automatic_insert", function() {
    var stop_id = $(this).closest("[data-stop-id]").attr("data-stop-id");

    var dialog = bootstrap_dialog($.extend(modal_options(), {
      title: I18n.t('plannings.edit.dialog.automatic_insert.title'),
      message: SMT['modals/default_with_progress']({
        msg: I18n.t('plannings.edit.dialog.automatic_insert.in_progress')
      })
    })).modal({
      keyboard: false,
      show: true
    });
    automaticInsertStops([stop_id], {
      complete: function() {
        dialog.modal('hide');
        completeAjaxMap();
      },
      success: function(data) {
        updatePlanning(data);
        enlightenStop({id: stop_id});
        map.closePopup();
      }
    });
  });

  $(".main").on("click", ".automatic_insert_all", function() {
    if ($('#out_of_route .route-info').data('size-active') > 20) {
      alert(I18n.t('plannings.edit.automatic_insert_too_many'));
      return false;
    }
    if (confirm(I18n.t('plannings.edit.automatic_insert_confirm'))) {
      var dialog = bootstrap_dialog($.extend(modal_options(), {
        title: I18n.t('plannings.edit.dialog.automatic_insert.title'),
        message: SMT['modals/default_with_progress']({
          msg: I18n.t('plannings.edit.dialog.automatic_insert.in_progress')
        })
      })).modal({
        keyboard: false,
        show: true
      });
      automaticInsertStops([], {
        complete: function() {
          dialog.modal('hide');
          completeAjaxMap();
          map.closePopup();
        }
      });
    }
  });

  $(".main").on('change', 'input:checkbox.stop_active', function(event) {
    var route_id = $(event.target).closest("[data-route-id]").attr("data-route-id");
    var stop_id = $(event.target).closest("[data-stop-id]").attr("data-stop-id");
    var active = $(event.target).is(':checked');
    $.ajax({
      type: 'PATCH',
      data: JSON.stringify({
        stop: {
          active: active
        }
      }),
      contentType: 'application/json',
      url: '/plannings/' + planning_id + '/' + route_id + '/' + stop_id + '.js',
      beforeSend: beforeSendWaiting,
      success: function() {
        updateSuccess(locals.summary, map, locals.updated_routes, {skipCallbacks: true});
        routesLayer.refreshRoutes(locals.updated_routes.map(route => route.route_id), locals.summary.routes);
      },
      complete: completeAjaxMap,
      error: ajaxError
    });
  });

  $(".main").on("click", ".send_to_route", function() {
    var route_id = $(this).closest("[data-route-id]").attr("data-route-id");
    var stopId = $(this).closest("[data-stop-id]").attr("data-stop-id");
    var url = this.href;
    var matches = url.match(new RegExp('([0-9]+)/([0-9]+)/move'));
    $.ajax({
      type: 'PATCH',
      url: url,
      beforeSend: function() {
        beforeSendWaiting();
        sortLoading($(`.route[data-route-id="${matches[1]}"]`), route_id);
      },
      success: function(data, _status, xhr) {
        if (xhr.status === 204) return;

        data.route_ids.forEach(function(route_id) {
          refreshSidebarRoute(planning_id, route_id);
        });
        routesLayer.refreshRoutes(data.route_ids, data.summary.routes);
        map.closePopup();
      },
      complete: function() {
        enlightenStop({id: stopId});
        completeAjaxMap();
      },
      error: ajaxError
    });
    return false;
  });

  var displayPlanningFirstTime = function(data) {

    // WARNING: data can be without routes here in case of optimization with delayed job
    displayPlanning(data, {
      firstTime: true
    });
  };

  var checkForDisplayPlanningFirstTime = function(data) {
    if (data.outdated) {

      var displayPlanningAfterModal = function() {
        var cursorBody = $('body').css('cursor');
        var cursorMap = $('#map').css('cursor');
        $('body, #map').css({
          cursor: 'progress'
        });
        setTimeout(function() {
          displayPlanningFirstTime(data);
          $('body').css({
            cursor: cursorBody
          });
          $('#map').css({
            cursor: cursorMap
          });
        }, 100);
      };

      $('#planning-refresh-modal').modal({
        keyboard: true,
        show: true
      });
      $("#refresh-modal").click(function() {
        $('#refresh').prop('disabled', true);
        $('#planning-refresh-modal').off('hidden.bs.modal');
        $('#planning-refresh-modal').modal('hide');
        $.ajax({
          type: 'GET',
          url: '/plannings/' + planning_id + '/refresh.json?with_stops=' + withStopsInSidePanel,
          beforeSend: beforeSendWaiting,
          success: displayPlanningFirstTime,
          complete: completeAjaxMap,
          error: ajaxError
        });
      });
      $('#planning-refresh-modal').on('hidden.bs.modal', displayPlanningFirstTime(data));
    } else {
      displayPlanningFirstTime(data);
    }
  };

  $('.btn.extend').click(function() {
    var routes = $(".routes");
    if ($("#planning.routes").hasClass('ui-sortable')) {
      routes.sortable('destroy');
    }
    routes.sortable();
    var sidebar = $('.sidebar');
    sidebar.toggleClass('extended');
    if (sidebar.hasClass('extended')) {
      $('#toggle_routes_dropdown_button').attr('disabled', true);
      sidebar.find('.toggle').prop('disabled', true);
      sidebar.find('.center_view').prop('disabled', true);
    } else {
      routes.sortable("destroy");
      $('#toggle_routes_dropdown_button').removeAttr('disabled');
      routes.find('.route-tools').each(function(_idx, elem) {
        if (!!$(elem).find('.toggle', 'fa-eye-slash')) {
          sidebar.find('.toggle').removeAttr('disabled');
        }
        sidebar.find('.center_view').removeAttr('disabled');
      });
    }

    $(".route-btn-group").each(function(idx, elem) {
      $(elem).toggleClass("pull-right");
    })
  });

  $.ajax({
    url: '/plannings/' + planning_id + '.json?with_stops=' + withStopsInSidePanel,
    beforeSend: beforeSendWaiting,
    success: checkForDisplayPlanningFirstTime,
    complete: completeAjaxMap,
    error: ajaxError
  });

  if (zoning_ids && zoning_ids.length > 0) {
    $.each(zoning_ids, function(i, zoningId) {
      $.ajax({
        type: 'GET',
        url: "/api/0.1/zonings/" + zoningId + ".json",
        beforeSend: beforeSendWaiting,
        success: displayZoning,
        complete: completeAjaxMap,
        error: ajaxError
      });
    });
  }

  var initPlanningDisplay = function(planning_id, options) {
    $.ajax({
      type: 'GET',
      url: '/plannings/' + planning_id + '/sidebar.js',
      beforeSend: beforeSendWaiting,
      error: ajaxError,
      success: function() {
        updateSuccess(locals.summary, map, locals.routes);
        initRouteSelector();
        updateSelectionCount('#route_selector', '#planning_route_ids');
      },
      complete: completeAjaxMap
    });

    if (options.firstTime) {
      externalCallbackUrl();
      routesLayer.showAllRoutes({stores: true}, function() {
        if (options.fitBounds) {
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
    }
    else {
      routesLayer.showAllRoutes();
    }

    $('#refresh').click(function() {
      $(this).prop('disabled', true);
      $.ajax({
        type: 'GET',
        url: '/plannings/' + planning_id + '/refresh.json?with_stops=' + withStops,
        beforeSend: beforeSendWaiting,
        success: displayPlanningFirstTime,
        complete: completeAjaxMap,
        error: ajaxError
      });
    });
  }

  var dialog_optimizer;
  var initOptimizerDialog = function() {
    hideNotices(); // Clear Failed Optimization Notices

    dialog_optimizer = bootstrap_dialog({
      title: I18n.t('plannings.edit.dialog.optimizer.title'),
      icon: 'fa-gear',
      message: SMT['modals/optimize']({
        i18n: mustache_i18n
      }),
      footer: '<div class="optim-duration col-xs-6">'
          + '<h5>' + I18n.t('plannings.edit.dialog.optimization.optimization_time') + '</h5>'
          + '<div id="min-optim-duration"></div>'
          + '<div id="max-optim-duration"></div>'
          + '</div>'
          + '<button class="optim-cancel btn btn-warning">' + I18n.t('plannings.edit.dialog.optimization.cancel') + '</button>'
          + '<button type="button" class="btn btn-primary" data-dismiss="modal">' + I18n.t('web.dialog.close') + '</button>'
    });
    $('#default-modal').data('canceled', false);

    $(".optim-duration h5").prop('title', I18n.t('plannings.edit.dialog.optimization.optimize-title'));
    dialog_optimizer.on('click', '.optim-cancel', function() {
      var element = $(this);
      $.ajax({
        type: 'DELETE',
        url: '/plannings/' + planning_id + '/optimize.json',
        success: function() {
          element.attr('disabled', true);
          element.text(I18n.t('plannings.edit.dialog.optimization.canceling'));
          $('#default-modal').data('canceled', true);
        },
        complete: completeAjaxMap,
        error: ajaxError
      });
    });
  };
  initOptimizerDialog();

  $('#optimize').click(function() {
    initOptimizerDialog();

    optimizationTimer.displayOptimDuration();
    var routeId = $('#optimization-route_id').val();
    var ignore_overload_multipliers = Array();
    $("input[name^='overload_multiplier']:checked").each(function () {
      if ($(this).val() == 'ignore')
        ignore_overload_multipliers.push({unit_id: $(this).attr('unit-id'), ignore: true})
    })
    $.ajax({
      type: 'GET',
      url: '/plannings/' + planning_id + (routeId ? '/' + routeId : '') + '/optimize.js',
      data: {
        with_stops: routeId ? true : withStopsInSidePanel,
        active_only: $('input[name="active_only"]:checked').val(),
        global: !routeId && (($('input[name="sticky_vehicle"]:checked').val() == 'true') ? 'false' : 'true'),
        ignore_overload_multipliers: ignore_overload_multipliers,
        nb_route: optimizationTimer.getNbRoute(),
        enable_optimization_soft_upper_bound: $('input[name="enable_optimization_soft_upper_bound"]:checked').val(),
        vehicle_max_upper_bound: $('input[name="vehicle_max_upper_bound"]').val(),
        stop_max_upper_bound: $('input[name="stop_max_upper_bound"]').val()
      },
      beforeSend: beforeSendWaiting,
      success: function() {
        var options = {
          error: function() {
            stickyError(I18n.t('plannings.edit.optimize_failed'));
          },
          success: function() {
            if ($('#default-modal').data('canceled')) {
              notice(I18n.t('plannings.edit.optimize_canceled'));
            } else {
              notice(I18n.t('plannings.edit.optimize_complete'));
            }
          }
        };
        if (locals.optimizer) {
          displayOptimModal(locals, options)
        }
        else if (locals.updated_routes) {
          updateSuccess(locals.summary, map, locals.updated_routes, {skipCallbacks: true});
          routesLayer.refreshRoutes(locals.updated_routes.map(route => route.route_id), locals.updated_routes);
        }
      },
      complete: completeAjaxMap,
      error: ajaxError
    });
  });

  $('.send_sms').click(sendSMS);
  $('.historize').click(historize);

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

  spreadsheetModalExport(params.spreadsheet_columns, params.planning_id, params.export_settings);

  var devicesObservePlanning = (function() {

    var _context;

    var _setLastSentAt = function(route) {
      var container = $("[data-route-id='" + route.id + "'] .last-sent-at", _context);
      route.i18n = mustache_i18n;
      container.html(SMT['routes/last_sent_at'](route));
      if (route.last_sent_at) {
        _showLastSentAt(route);
      } else {
        _clearLastSentAt(route);
      }
    };

    var _setPlanningRoutesLastSentAt = function(routes) {
      $.each(routes, function(i, route) {
        _setLastSentAt(route);
      });
    };

    var _clearLastSentAt = function(route) {
      $("[data-route-id='" + route.id + "'] .last-sent-at", _context).hide();
    };

    var _showLastSentAt = function(route) {
      $("[data-route-id='" + route.id + "'] .last-sent-at", _context).show();
    };

    var _clearPlanningRoutesLastSentAt = function(routes) {
      $.each(routes, function(i, route) {
        _clearLastSentAt(route);
      });
    };

    var _devicesInitVehicle = function(callback) {

      $.each($('.last-sent-at', _context), function(i, element) {
        if ($(element).find('span').html() === '') $(element).hide();
      });

      $(_context).off('click', '.device-operation').on('click', '.device-operation', function(e) {
        var from = $(e.target),
          service = from.data('service'),
          operation = from.data('operation'),
          url = '/api/0.1/devices/' + service + '/' + operation,
          data = {};

        if (from.data('planning-id')) data.planning_id = from.data('planning-id');
        if (from.data('route-id')) data.route_id = from.data('route-id');
        if (from.data('type')) data.type = from.data('type');
        if (from.data('sync-user')) data.sync_user = from.data('sync-user');

        if (operation != 'fetch_routes' && !confirm(I18n.t('all.verb.confirm'))) {
          return;
        }

        var serviceInProgress = 'plannings.edit.dialog.' + service + '.in_progress';
        var serviceTitle = 'plannings.edit.dialog.' + service + '.title';
        var dialog = bootstrap_dialog({
          icon: 'fa-bars',
          replaceOnlyModalIcon: true,
          title: I18n.t(serviceTitle),
          message: SMT['modals/default_with_spinner']({
            msg: I18n.t(serviceInProgress)
          }),
          dataDismiss: true
        });

        url += ((data.planning_id && operation !== 'fetch_routes') ? '_multiple' : '');
        var schema;

        switch (operation) {
        case 'clear':
          schema = 'DELETE';
          break;
        case 'fetch_routes':
          schema = 'GET';
          break;
        default:
          schema = 'POST';
          break;
        }

        $.ajax({
          url: url,
          type: schema,
          dataType: 'json',
          data: data,
          beforeSend: function() {
            dialog.modal('show');
          },
          success: function(data) {
            if (data && data.error) {
              stickyError(data.error);
            } else {
              var serviceTranslation = 'plannings.edit.' + service + '_' + operation +
                (from.data('type') ? '_' + from.data('type') : '') +
                (from.data('route-id') ? '.singular' : '.plural') + '.success';
              if (operation !== 'fetch_routes') notice(I18n.t(serviceTranslation));

              if (from.data('planning-id') && operation === 'send')
                _setPlanningRoutesLastSentAt(data);
              else if (from.data('planning-id') && operation === 'clear')
                _clearPlanningRoutesLastSentAt(data);
              else if (from.data('route-id') && operation === 'send')
                _setLastSentAt(data);
              else if (from.data('route-id') && operation === 'clear')
                _clearLastSentAt(data, _context);
              else if (operation === 'fetch_routes') {
                if (from.data('user-label')) data.push({user_label: from.data('user-label')});
                if (from.data('user-color')) data.push({user_color: from.data('user-color')});
                _fetchFleetRoutes(data);
              }

              callback && callback(from); // for backgroundTask
            }
          },
          complete: function() {
            dialog.modal('hide');
          },
          error: function() {
            var serviceErrorTranslation = 'plannings.edit.' + service + '_' + operation +
              (from.data('type') ? '_' + from.data('type') : '') +
              (from.data('route-id') ? '.singular' : '.plural') + '.fail';
            stickyError(I18n.t(serviceErrorTranslation));
          }
        });

        // Reset Dropdown
        $(this).closest(".dropdown-menu").prev().dropdown("toggle");
        return false;
      });
    };

    var init = function(context, callback) {
      _context = context;
      _devicesInitVehicle(callback);
    };

    return { init: init };

  })();

  // Init device global tools
  devicesObservePlanning.init($('#edit-planning'));
};

var plannings_show = function(params) {

  if (!params.print_map) {
    window.print();
  } else {
    $('.btn-print').click(function() {
      window.print();
    });
  }
};

var plannings_index = function(params) {

  var requestPending = false;

  iCalendarExport();
  spreadsheetModalExport(params.spreadsheet_columns, null, params.export_settings);

  var vehicle_id = $('#vehicle_id').val(),
    planning_ids;

  var templateVehicle = function(vehicle) {
    if (vehicle.id)
      return $("<span><span class='color_small' style='background: " + params.vehicles[vehicle.id].color + "'></span>&nbsp;</span>").append($("<span/>").text(vehicle.text));
  };

  $('#vehicle_id').select2({
    // theme: 'bootstrap',
    templateSelection: templateVehicle,
    templateResult: templateVehicle
  }).change(function() {
    vehicle_id = $(this).val();
  });

  $('#external-url').on('click', function(e) {
    e.preventDefault();

    planning_ids = $('[name^=planning]:checked').map(function() { return $(this).val(); }).toArray().join(',');
    if (!requestPending) {
      requestPending = true;
      $.ajax({
        type: 'POST',
        url: '/customers/' + params.customer_id + '/external_callback',
        data: { api_key: params.user_api_key, planning_ids: planning_ids },
        success: function() { notice(I18n.t('plannings.edit.export.customer_external_callback_url.success')); },
        error: function() { stickyError(I18n.t('plannings.edit.export.customer_external_callback_url.fail')); },
        complete: function() { requestPending = false; }
      });
    }
  });

  $('#routes-by-vehicle').on('click', function(e) {
    e.preventDefault();
    if (!vehicle_id) {
      return warning(I18n.t('plannings.index.vehicle_select_error'));
    }
    planning_ids = $('[name^=planning]:checked').map(function() { return $(this).val(); }).toArray().join(',');
    location.assign('/routes_by_vehicles/' + vehicle_id + '?planning_ids=' + planning_ids);
  });

  $('#deliverables-by-vehicle').on('click', function(e) {
    e.preventDefault();
    if (!vehicle_id) {
      return warning(I18n.t('plannings.index.vehicle_select_error'));
    }
    planning_ids = $('[name^=planning]:checked').map(function() { return $(this).val(); }).toArray().join(',');
    location.assign('/deliverables_by_vehicles/' + vehicle_id + '?planning_ids=' + planning_ids);
  });

};

Paloma.controller('Plannings', {
  index: function() {
    plannings_index(this.params);
  },
  new: function() {
    plannings_new(this.params);
  },
  create: function() {
    plannings_new(this.params);
  },
  edit: function() {
    plannings_edit(this.params);
  },
  update: function() {
    plannings_edit(this.params);
  },
  show: function() {
    plannings_show(this.params);
  }
});
