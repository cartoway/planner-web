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

import { customColorInitialize, routerOptionsSelect , templateTag } from '../../assets/javascripts/scaffolds';
import { selectTag } from './tags';

const vehicle_usages_form = function(params) {
  $("select#vehicle_usage_store_reload_ids").select2({
    theme: 'bootstrap',
    minimumResultsForSearch: 5,
    width: '100%',
    tags: true,
    closeOnSelect: false,
  });

  /* Speed Multiplier */
  $('form.number-to-percentage').submit(function(e) {
    $.each($(e.target).find('input[type=\'number\'].number-to-percentage'), function(i, element) {
      var value = $(element).val() ? Number($(element).val()) / 100 : null;
      $($(document.createElement('input')).attr('type', 'hidden').attr('name', 'vehicle_usage[vehicle][' + $(element).attr('name') + ']').val(value)).insertAfter($(element));
    });
    return true;
  });

  $('#vehicle_usage_open, #vehicle_usage_close, #vehicle_usage_rest_start, #vehicle_usage_rest_stop, #vehicle_usage_rest_duration, #vehicle_usage_service_time_start, #vehicle_usage_service_time_end, #vehicle_usage_work_time, #vehicle_usage_vehicle_max_ride_duration').timeEntry({
    show24Hours: true,
    spinnerImage: '',
    defaultTime: '00:00'
  });

  $('#vehicle_usage_vehicle_color').simplecolorpicker({
    theme: 'fontawesome'
  });

  customColorInitialize('#vehicle_usage_vehicle_color');

  $('#capacity-unit-add').click(function(event) {
    $(this).hide();
    $('#vehicle_usage_vehicle_capacity_input').find('.input-group').show();
    event.preventDefault();
    return false;
  });

  /* API: Devices */
  devicesObserveVehicle.init(params);

  routerOptionsSelect('#vehicle_usage_vehicle_router', params);

  var noResults = I18n.t('vehicles.form.tags_empty');
  $('select[name$=\\[tag_ids\\]\\[\\]]', '#vehicle_usage_vehicle_tag_ids_input').select2({
    theme: 'bootstrap',
    minimumResultsForSearch: -1,
    templateSelection: templateTag,
    templateResult: templateTag,
    language: {
      noResults: function() {
        return noResults;
      }
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

  $('select[name$=\\[tag_ids\\]\\[\\]]', '#vehicle_usage_tag_ids_input').select2({
    theme: 'bootstrap',
    minimumResultsForSearch: -1,
    templateSelection: templateTag,
    templateResult: templateTag,
    language: {
      noResults: function() {
        return noResults;
      }
    },
    width: '100%'
  });
};

const devicesObserveVehicle = (function() {
  var _buildSelect = function(name, datas) {
    var el = $('[data-device=' + name + ']');
    var options = {
      data: datas || [],
      theme: 'bootstrap',
      width: '100%',
      allowClear: true, // Need a placeholder
      placeholder: '',
      minimumResultsForSearch: 5,
      templateResult: function(data_selection) {
        return data_selection.text;
      },
      templateSelection: function(data_selection) {
        return data_selection.text;
      }
    }

    if (el.attr('name').includes("ids")) {
      options.allowClear = false;
      options.multiple = true;
    }

    el.select2(options);
  };

  // this is used to set a default value for select2 builder - Update datas from ajax request
  var _addDataToSelect2 = function(name, datas, devices) {
    _buildSelect(name, datas);
    var el = $('[data-device=' + name + ']');
    el.val(devices[name + "_id"] || devices[name + "_ids"] || devices[name + "_vehicle_id"] || devices[name + "_ref"] || devices[name + "_user"] || datas[0])
      .trigger("change");
  };

  var _devicesInitVehicle = function(name, params) {
    _buildSelect(name, params.devices);
    $.ajax({
      url: '/api/0.1/devices/' + name + '/devices.json',
      data: {
        customer_id: params.customer_id
      },
      dataType: 'json',
      success: function(data) {
        // Blank option
        if (data && data.error) stickyError(data.error);
        _addDataToSelect2(name, data, params.devices);
      },
      error: function(jqXHR, textStatus, errorThrown) {
        var err = (jqXHR && jqXHR.responseJSON && jqXHR.responseJSON.message) ? jqXHR.responseJSON.message : errorThrown;
        stickyError(err);
      }
    });
  };

  var init = function(params) {
    $.each($("[data-device]"), function(i, deviceSelect) {
      _devicesInitVehicle($(deviceSelect).data('device'), params);
    });
  };

  return { init: init };
})();

Paloma.controller('VehicleUsages', {
  new: function() {
    vehicle_usages_form(this.params);
  },
  create: function() {
    vehicle_usages_form(this.params);
  },
  edit: function() {
    vehicle_usages_form(this.params);
  },
  update: function() {
    vehicle_usages_form(this.params);
  },
  toggle: function() {
    vehicle_usages_form(this.params);
  }
});
