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

const vehicle_usage_sets_index = function(params) {
  const showAccordionCheckElements = function(show) {
    ['[id^=vehicle_usage_sets_]', '#add', '.btn-destroy'].map(function(str) {
      show ? $(str).removeClass('invisible') : $(str).addClass('invisible');
    });
  };

  // override accordion collapse bootstrap code
  $('a.accordion-toggle').click(function() {
    var id = $(this).attr('href');
    window.location.hash = id;
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
