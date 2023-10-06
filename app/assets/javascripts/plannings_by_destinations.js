import { bootstrap_dialog, modal_options } from '../javascripts/scaffolds'
import { ajaxError, beforeSendWaiting, completeWaiting } from '../javascripts/ajax';

/* global bootstrap_dialog modal_options */
const planningsShow = function(params) {
  'use strict';
  var planningQuantities = [];
  var vehiclesUsagesByPlanning = [];

  const templateVehicle = function(vehicle) {
    if (vehicle.id)
      return $("<span><span class='color_small' style='background: " + params.vehicles[parseInt(vehicle.id)].color + "'></span>&nbsp;</span>").append($("<span/>").text(vehicle.text));
  };

  const getSelectedVisits = function() {
    return $('#visits').find('input:checkbox:visible:checked');
  };

  const getSelectedPlannings = function(objName) {
    var visits = getSelectedVisits();
    var list = [];
    for (var index = 0; index < visits.length; index++) {
      if (!list[$(visits[index]).data('planning')]) list[$(visits[index]).data('planning')] = [];
      list[$(visits[index]).data('planning')].push($(visits[index]).data(objName));
    }
    return list;
  };

  var movedDestinations;
  const countMovedDestinations = function(max) {
    movedDestinations++;
    $('.progress-bar').css('width', (movedDestinations * 100 / max) + '%');
    if (movedDestinations == max) location.href = '';
  };

  const getQuantitiesByPlanning = function() {
    var quantitiesByPlanning = $('#visits .stop-id:checked:visible');
    var selectedStops = {};
    for (var index = 0; index < quantitiesByPlanning.length; index++) {
      var stopId = $(quantitiesByPlanning[index]).data('stop');
      var planningId = $(quantitiesByPlanning[index]).data('planning');
      var quantitiesElements = $('.quantity-' + stopId);
      var quantities = [];
      for (var idx = 0; idx < quantitiesElements.length; idx++) {
        var $quantity = $(quantitiesElements[idx]);
        quantities.push({
          quantity: parseFloat($quantity.data('quantity')),
          deliverable_unit_id: $quantity.data('deliverable-unit-id'),
          unit_icon: $quantity.data('unit-icon')
        });
      }

      if (selectedStops[planningId]) {
        selectedStops[planningId].quantities.forEach(function(quantity) {
          quantities.forEach(function(qt) {
            if (quantity.deliverable_unit_id == qt.deliverable_unit_id)
              quantity.quantity += qt.quantity;
          });
        });
      } else {
        selectedStops[planningId] = {
          planningId: planningId,
          duration: null,
          quantities: quantities
        };
      }
    }
    return selectedStops;
  };

  const getStopsToMoveByPlanning = function() {
    var stopsToMoveByPlanning = {};
    var stopsToMoveByPlanningElement = $('#visits .stop-id:checked:visible');
    for (var index = 0; index < stopsToMoveByPlanningElement.length; index++) {
      var stopByPlanning = stopsToMoveByPlanningElement[index];
      if (stopsToMoveByPlanning[$(stopByPlanning).data('planning')]) {
        stopsToMoveByPlanning[$(stopByPlanning).data('planning')].push($(stopByPlanning).data('visit'));
      } else {
        stopsToMoveByPlanning[$(stopByPlanning).data('planning')] = [];
        stopsToMoveByPlanning[$(stopByPlanning).data('planning')].push($(stopByPlanning).data('visit'));
      }
    }
    return stopsToMoveByPlanning;
  };

  const getVehicleCapacities = function(vehicleId, planningId) {
    if (!vehicleId) return [];
    var capacities = vehiclesUsagesByPlanning[planningId][vehicleId];
    return Object.keys(capacities.default_capacities).map(function(id) {
      var quantity = $.grep(planningQuantities[planningId], function(obj){return obj.id === parseInt(id);})[0]
      if (quantity) return {id: id, capacity: capacities.default_capacities[id], label: quantity.label, unitIcon: quantity.unit_icon};
    }).filter(function(element) { return element; });
  };

  const getVehicleQuantities = function(vehicleId, planningId) {
    if (!vehicleId) return [];
    return [{ quantities: vehiclesUsagesByPlanning[planningId][vehicleId].vehicle_quantities }];
  };

  const modifyVehicle = function(vehicleElement, planningId) {
    $('#planning-list .vehicle-color[data-planning-id="' + planningId + '"]')
      .css('background', vehicleElement.color);
    $('#planning-list .vehicle-name[data-planning-id="' + planningId + '"]')
      .html(vehicleElement.value);
    $('#planning-list-' + planningId).show();
  };

  const cleanUncheckedQuantities = function() {
    var uncheckedVisits = $('#visits .stop-id:visible:not(:checked)');
    for (var index = 0; index < uncheckedVisits.length; index++) {
      var $element = $(uncheckedVisits[index]);
      $('.vehicle-projected-quantities[data-planning-id="' + $element.data('planning') + '"]').empty();
      modifyVehicle({color: '', value: ''}, $element.data('planning'));
      $('#planning-list-' + $element.data('planning')).hide();
    }
  };

  const getVehiclesUsagesByPlanning = function(planningId, fnct) {
    $.ajax({
      type: 'GET',
      dataType: 'json',
      url: '/api/0.1/plannings/' + planningId + '/vehicle_usages?api_key=' + params.user_api_key,
      beforeSend: beforeSendWaiting,
      error: function(request, status, error) {
        ajaxError(request, status, error);
        completeWaiting();
      },
      success: function(data) {
        vehiclesUsagesByPlanning[planningId] = data;
        completeWaiting();
        fnct();
      }
    });
  };

  const getPlanningQuantities = function(planningId, fnct) {
    $.ajax({
      type: 'GET',
      dataType: 'json',
      url: '/api/0.1/plannings/' + planningId + '/quantities?api_key=' + params.user_api_key,
      beforeSend: beforeSendWaiting,
      error: function(request, status, error) {
        ajaxError(request, status, error);
        completeWaiting();
      },
      success: function(data) {
        planningQuantities[planningId] = data;
        completeWaiting();
        fnct();
      }
    });
  };

  const renderData = function(steped, objct) {
    if (steped !== 2) return;
    objct.stopsToMoveByPlanning[objct.planningId].forEach(function() {
      modifyVehicle({color: objct.$vehicleElement.data('color'), value: objct.$vehicleElement.html()}, objct.planningId);
      var quantitiesToCalculate = $('.vehicle-projected-quantities[data-planning-id="' + objct.planningId + '"]');
      for (var qtIndex = 0; qtIndex < quantitiesToCalculate.length; qtIndex++) {
        var $element = $(quantitiesToCalculate[qtIndex]);
        var vehicleId = objct.$vehicleElement.val();
        var vehicleCapacities = getVehicleCapacities(vehicleId, objct.planningId);
        var globalVisits = getVehicleQuantities(vehicleId, objct.planningId);
        globalVisits.push(objct.visitToMove);
        $element.empty();
        $element.fillQuantities({
          vehicleCapacities: vehicleCapacities,
          stops: globalVisits,
          controllerParamsQuantities: planningQuantities[objct.planningId],
          withCapacity: true,
        });
      }
    });
  };

  const calculateCapacities = function() {
    cleanUncheckedQuantities();
    var quantitiesByPlanning = getQuantitiesByPlanning();
    var $vehicleElement = $('#vehicle-id').find(":selected");
    if (!$vehicleElement.data('id')) return;
    Object.keys(quantitiesByPlanning).forEach(function(planningId) {
      var visitToMove = quantitiesByPlanning[planningId];
      var stopsToMoveByPlanning = getStopsToMoveByPlanning();
      var ready = 0;
      if (vehiclesUsagesByPlanning[planningId]) {
        ready++;
        renderData(ready, {
          stopsToMoveByPlanning: stopsToMoveByPlanning,
          planningId: planningId,
          $vehicleElement: $vehicleElement,
          visitToMove: visitToMove
        });
      } else {
        getVehiclesUsagesByPlanning(planningId, function() {
          ready++;
          renderData(ready, {
            stopsToMoveByPlanning: stopsToMoveByPlanning,
            planningId: planningId,
            $vehicleElement: $vehicleElement,
            visitToMove: visitToMove
          });
        });
      }
      if (planningQuantities[planningId]) {
        ready++;
        renderData(ready, {
          stopsToMoveByPlanning: stopsToMoveByPlanning,
          planningId: planningId,
          $vehicleElement: $vehicleElement,
          visitToMove: visitToMove
        });
      } else {
        getPlanningQuantities(planningId, function() {
          ready++;
          renderData(ready, {
            stopsToMoveByPlanning: stopsToMoveByPlanning,
            planningId: planningId,
            $vehicleElement: $vehicleElement,
            visitToMove: visitToMove
          });
        });
      }
    });
  };

  $('#affect-destinations').click(function() {
    var vehicleId = parseInt($('#vehicle-id').find(":selected").val());
    var dialog = bootstrap_dialog($.extend(modal_options(), {
      title: I18n.t('plannings.edit.dialog.move_destinations.title'),
      message: SMT['modals/default_with_progress']({
        msg: I18n.t('plannings.edit.dialog.move_destinations.in_progress')
      })
    }));
    $('.progress-bar').css('width', 0);
    dialog.modal({ keyboard: false, show: true });

    movedDestinations = 0;
    var selectedPlannings = getSelectedPlannings('visit');
    selectedPlannings.forEach(function(stopIds, planningId) {
      var routeId = params.routesByVehiclesByPlanning[planningId][vehicleId];
      $.ajax({
        type: 'PATCH',
        dataType: 'json',
        url: '/api/0.1/plannings/' + planningId + '/routes/' + routeId + '/visits/moves',
        data: { 'visit_ids': stopIds },
        beforeSend: beforeSendWaiting,
        error: function(request, status, error) {
          dialog.modal('hide');
          ajaxError(request, status, error);
          completeWaiting();
        },
        success: function() { countMovedDestinations(Object.keys(selectedPlannings).length); }
      });
    });
  });

  $('#automatic-insert').click(function() {
    var dialog = bootstrap_dialog($.extend(modal_options(), {
      title: I18n.t('plannings.edit.dialog.automatic_insert.title'),
      message: SMT['modals/default_with_progress']({
        msg: I18n.t('plannings.edit.dialog.automatic_insert.in_progress')
      })
    }));
    $('.progress-bar').css('width', 0);
    dialog.modal({ keyboard: false, show: true });

    movedDestinations = 0;
    var selectedPlannings = getSelectedPlannings('stop');
    selectedPlannings.forEach(function(stopIds, planningId) {
      $.ajax({
        type: 'PATCH',
        dataType: 'json',
        url: '/api/0.1/plannings/' + planningId + '/automatic_insert',
        data: { 'stop_ids': stopIds },
        beforeSend: beforeSendWaiting,
        error: function(request, status, error) {
          dialog.modal('hide');
          ajaxError(request, status, error);
          completeWaiting();
        },
        success: function() { countMovedDestinations(Object.keys(selectedPlannings).length); }
      });
    });
  });

  $('#vehicle-id').select2({
    templateSelection: templateVehicle,
    templateResult: templateVehicle
  }).change(function() { calculateCapacities(); });
  $('#visits_filter').on('table.filtered', function() {
    calculateCapacities();
  });
  $('#visits .stop-id').change(function() { calculateCapacities(); });
};

$(document).ready(function() {
  $('.overflow').css('max-height', ($(window).height() - 250) + 'px');
});

Paloma.controller('PlanningsByDestinations', {
  show: function() {
    planningsShow(this.params);
  }
});
