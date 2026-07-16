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

import { bootstrap_dialog, modal_options } from '../../assets/javascripts/scaffolds';
import { beforeSendWaiting, completeWaiting, ajaxError } from './ajax';

const persistVehicleUsageOrder = function($tbody) {
  var vehicleUsageSetId = $tbody.attr('data-vehicle-usage-set-id');
  var vehicleUsageIds = $tbody.find('tr[data-vehicle-usage-id]').map(function() {
    return parseInt($(this).attr('data-vehicle-usage-id'), 10);
  }).get();

  $.ajax({
    type: 'PATCH',
    url: '/vehicle_usage_sets/' + vehicleUsageSetId + '/reorder_vehicle_usages',
    data: {
      authenticity_token: $('meta[name="csrf-token"]').attr('content'),
      vehicle_usage_ids: vehicleUsageIds
    },
    beforeSend: beforeSendWaiting,
    complete: completeWaiting,
    error: ajaxError
  });
};

const compareVehicleUsageRows = function($left, $right, field, direction) {
  var multiplier = direction === 'desc' ? -1 : 1;
  if (field === 'id') {
    return multiplier * ($left.data('vehicleId') - $right.data('vehicleId'));
  }
  if (field === 'name') {
    return multiplier * String($left.data('vehicleName') || '').localeCompare(
      String($right.data('vehicleName') || ''),
      undefined,
      { sensitivity: 'base' }
    );
  }
  return multiplier * String($left.data('routerSort') || '').localeCompare(
    String($right.data('routerSort') || ''),
    undefined,
    { sensitivity: 'base' }
  );
};

const sortVehicleUsages = function($tbody, field, direction) {
  var $rows = $tbody.find('tr[data-vehicle-usage-id]').get();
  $rows.sort(function(left, right) {
    return compareVehicleUsageRows($(left), $(right), field, direction);
  });
  $.each($rows, function(_index, row) {
    $tbody.append(row);
  });
  persistVehicleUsageOrder($tbody);
};

const initVehicleUsagesSortDropdown = function($scope) {
  $scope.find('.vehicle-usages-table').each(function() {
    var $table = $(this);
    var $tbody = $table.find('tbody.vehicle-usages-sortable--enabled');
    if (!$tbody.length) return;

    $table.find('.vehicle-usages-sort-dropdown .dropdown-menu a').off('click.vehicleUsagesSort').on('click.vehicleUsagesSort', function(event) {
      event.preventDefault();
      var $item = $(this).closest('li');
      sortVehicleUsages($tbody, $item.data('sortField'), $item.data('sortDirection'));
      $table.find('.vehicle-usages-sort-dropdown .dropdown-menu li').removeClass('active');
      $item.addClass('active');
    });
  });
};

const initVehicleUsagesSortable = function($tbodies) {
  $tbodies.each(function() {
    var $tbody = $(this);
    if ($tbody.hasClass('ui-sortable')) {
      $tbody.sortable('destroy');
    }
    $tbody.sortable({
      items: '> tr',
      handle: '.vehicle-usage-sort-handle',
      axis: 'y',
      helper: function(_event, $row) {
        var $originals = $row.children();
        var $helper = $row.clone();
        $helper.children().each(function(index) {
          $(this).width($originals.eq(index).width());
        });
        return $helper;
      },
      update: function() {
        persistVehicleUsageOrder($tbody);
      }
    });
  });
};

const vehicle_usage_sets_index = function(params) {
  const showAccordionCheckElements = function(show) {
    ['[id^=vehicle_usage_sets_]', '#add', '.btn-destroy'].map(function(str) {
      show ? $(str).removeClass('invisible') : $(str).addClass('invisible');
    });
  };

  // override accordion collapse bootstrap code
  $('a.accordion-toggle').click(function() {
    var id = $(this).attr('href');
    // Use replaceState to track accordion state without creating history entries
    if (history.replaceState) {
      history.replaceState(null, '', id);
    }
    var allCollapsed = $('.accordion-body.collapse.in').size() ? true : false;
    $('.accordion-body.collapse.in').each(function() {
      var $this = $(this);
      if (id !== '#' + $this.attr('id')) {
        allCollapsed = false;
        $this.collapse('hide');
      }
    });
    showAccordionCheckElements(allCollapsed);
  });

  $('#add').click(function() {
    $('.deleter-check').prop('checked', !$('.deleter-check').is(':checked')).change();
  });

  $('.select-unselect-all').click(function() {
    var vehicleUsageSetId = $(this).attr('data-id');
    var isChecked = $(this).is(':checked');

    if (isChecked) {
      $('html, body').animate({
        scrollTop: $('#multiple-actions-' + vehicleUsageSetId).offset().top
      }, 1000);
    }

    $('#accordion-' + vehicleUsageSetId + ' tr .vehicle-select').each(function() {
      $(this).prop('checked', isChecked).change();
    });
  });

  var onVehicleSelected = function() {
    $('.select-unselect-all').each(function() {
      var vehicleUsageSetId = $(this).attr('data-id');
      if ($('.vehicle-select:checked', $(this).closest('tr')).length)
        $('#multiple-actions-' + vehicleUsageSetId + ' button, #multiple-actions-' + vehicleUsageSetId + ' select').attr('disabled', false);
      else
        $('#multiple-actions-' + vehicleUsageSetId + ' button, #multiple-actions-' + vehicleUsageSetId + ' select').attr('disabled', true);
    });
  };
  $('.vehicle-select').change(onVehicleSelected);
  onVehicleSelected();

  initVehicleUsagesSortable($('tbody.vehicle-usages-sortable--enabled'));
  initVehicleUsagesSortDropdown($(document));

  $('.accordion-body.collapse').on('shown.bs.collapse', function() {
    initVehicleUsagesSortable($('tbody.vehicle-usages-sortable--enabled', this));
    initVehicleUsagesSortDropdown($(this));
  });

  if (window.location.hash) {
    $('.accordion-body.collapse.in').each(function() {
      var $this = $(this);
      if (window.location.hash !== '#' + $this.attr('id')) {
        $this.removeClass('in');
      }
    });
    $(".accordion-toggle[href!='" + window.location.hash + "']").addClass('collapsed');
    $(window.location.hash).addClass('in');
    $(".accordion-toggle[href='" + window.location.hash + "']").removeClass('collapsed');
    showAccordionCheckElements(false);
  }
};

const vehicle_usage_sets_edit = function(params) {
  $("select#vehicle_usage_set_store_reload_ids").select2({
    theme: 'bootstrap',
    minimumResultsForSearch: 5,
    width: '100%',
    tags: true,
    closeOnSelect: false
  });

  $('#vehicle_usage_set_open, #vehicle_usage_set_close, #vehicle_usage_set_rest_start, #vehicle_usage_set_rest_stop, #vehicle_usage_set_rest_duration, #vehicle_usage_set_service_time_start, #vehicle_usage_set_service_time_end, #vehicle_usage_set_work_time, #vehicle_usage_set_max_ride_duration').timeEntry({
    show24Hours: true,
    spinnerImage: '',
    defaultTime: '00:00'
  });
};

const vehicle_usage_sets_import = function(params) {
  var dialogUpload = bootstrap_dialog({
    title: I18n.t('vehicle_usage_sets.import.dialog.import.title'),
    icon: 'fa-upload',
    message: SMT['modals/default_with_progress']({
      msg: I18n.t('vehicle_usage_sets.import.dialog.import.in_progress')
    })
  });

  $(":file").filestyle({
    buttonName: "btn-primary",
    iconName: "fa fa-folder-open",
    buttonText: I18n.t('web.choose_file')
  });

  $('form#new_import_csv').submit(function() {
    var confirmChecks = [];
    $('#import_csv_replace_vehicles', $(this)).is(':checked') && confirmChecks.push('replace_vehicles');
    if (confirmChecks.length > 0 && !confirm(confirmChecks.map(function(c) {
      var vehicle_usage_set_import_translation = 'vehicle_usage_sets.import.dialog.' + c + '_confirm';
      return I18n.t(vehicle_usage_set_import_translation);
    }).join(" \n"))) {
      return false;
    }

    dialogUpload.modal(modal_options());
  });
};

Paloma.controller('VehicleUsageSets', {
  index: function() {
    vehicle_usage_sets_index(this.params);
  },
  new: function() {
    vehicle_usage_sets_edit(this.params);
  },
  create: function() {
    vehicle_usage_sets_edit(this.params);
  },
  edit: function() {
    vehicle_usage_sets_edit(this.params);
  },
  update: function() {
    vehicle_usage_sets_edit(this.params);
  },
  import: function() {
    vehicle_usage_sets_import(this.params);
  },
  upload_csv: function() {
    vehicle_usage_sets_import(this.params);
  }
});
