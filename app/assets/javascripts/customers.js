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

import { beforeSendWaiting, completeWaiting, ajaxError } from '../../assets/javascripts/ajax';
import { routerOptionsSelect, mapInitialize } from '../../assets/javascripts/scaffolds';

const customers_index = function (params) {
  var map_layers = params.map_layers,
    map_attribution = params.map_attribution;

  var is_map_init = false;

  var map_init = function () {

    var map = mapInitialize(params);
    L.control.attribution({
      prefix: false
    }).addTo(map);

    var layer = L.featureGroup();
    map.addLayer(layer);


    function determineIconColor(customer) {

      var color = {
        isActiv: '558800', // green
        isNotActiv: '707070', // grey
        isTest: '0077A3' // blue
      };

      return customer.test ? color.isTest : (customer.isActiv ? color.isActiv : color.isNotActiv);

    }

    const display_customers = function (data) {
      $.each(data.customers, function (i, customer) {
        var iconImg = '/images/point-' + determineIconColor(customer) + '.svg';
        L.marker(new L.LatLng(customer.lat, customer.lng), {
          icon: new L.NumberedDivIcon({
            number: customer.max_vehicles,
            iconUrl: iconImg,
            iconSize: new L.Point(12, 12),
            iconAnchor: new L.Point(6, 6),
            popupAnchor: new L.Point(0, -6),
            className: "small"
          })
        }).addTo(layer).bindPopup(customer.name);
      });

      map.invalidateSize();

      if (layer.getLayers().length > 0) {
        map.fitBounds(layer.getBounds(), {
          maxZoom: 15,
          padding: [20, 20]
        });
      }

    };

    $.ajax({
      url: '/customers.json',
      beforeSend: beforeSendWaiting,
      success: display_customers,
      complete: completeWaiting,
      error: ajaxError
    });

  };

  $('#accordion').on('show.bs.collapse', function() {
    if (!is_map_init) {
      is_map_init = true;
      map_init();
    }
  });

  const onFilterChanged = function(text) {
    $('body').addClass('ajax_waiting');
    var customersCount = 0, customersNoTestCount = 0, vehiclesCount = 0, vehiclesNoTestCount = 0;
    var customersVisibility = {};
    $('#customers tbody tr').each(function(i, row) {
      var $row = $(row);
      var match = !text || $row.text().search(new RegExp(text.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"), 'i')) > -1;
      if (match) {
        var customerId = $row.data('customer_id');
        if (!customersVisibility[customerId]) {
          customersCount++;
          vehiclesCount += params.customers[customerId]['vehicles_count'];
          if (!params.customers[customerId]['test']) {
            customersNoTestCount++;
            vehiclesNoTestCount += params.customers[customerId]['vehicles_count'];
          }
        }
        customersVisibility[customerId] = true;
      }
    });
    $('#customers tbody tr').css('display', 'none');
    for (var i in customersVisibility) {
      $('[data-customer_id=' + i + ']').css('display', 'table-row');
    }
    $('#customers_count').text(customersCount);
    $('#customers_notest_count').text(customersNoTestCount);
    $('#vehicles_count').text(vehiclesCount);
    $('#vehicles_notest_count').text(vehiclesNoTestCount);
    $('body').removeClass('ajax_waiting');
  };
  var filterTimeoutId = null;
  $('#customers_filter').keyup(function() {
    if (filterTimeoutId)
      clearTimeout(filterTimeoutId);
    filterTimeoutId = setTimeout(function() {
      filterTimeoutId = null;
      onFilterChanged($('#customers_filter').val());
    }, 200);
  });
  var filterText = $('#customers_filter').val();
  if (filterText)
    onFilterChanged(filterText);
};

const customers_edit = function (params) {
  /* Speed Multiplier */
  $('form.number-to-percentage').submit(function (e) {
    $.each($(e.target).find('input[type=\'number\'].number-to-percentage'), function (i, element) {
      var value = $(element).val() ? Number($(element).val()) / 100 : 1;
      $($(document.createElement('input')).attr('type', 'hidden').attr('name', 'customer[' + $(element).attr('name') + ']').val(value)).insertAfter($(element));
    });
    return true;
  });

  /* API: Devices */
  devicesObserveCustomer.init($.extend(params, {
    // FIXME -> THE DEFAULT PASSWORD MUST BE DONE AT THE BACKEND LVL, WHICH MAKE NOT VISIBLE THE TRUE PASSWORD FROM DB
    default_password: Math.random().toString(36).slice(-8)
  }));

  $('#customer_end_subscription').datepicker({
    autoclose: true,
    calendarWeeks: true,
    todayHighlight: true,
    format: I18n.t("all.datepicker"),
    language: I18n.currentLocale(),
    zIndexOffset: 1000
  });

  $('#customer_visit_duration').timeEntry({
    show24Hours: true,
    showSeconds: true,
    initialField: 1,
    defaultTime: '00:00:00',
    spinnerImage: ''
  });

  const getLocaleFromCurrentLocale = function() {
    for (var locale in $.fn.wysihtml5.locale) {
      if (locale.indexOf(I18n.currentLocale()) !== -1) {
        return locale;
      }
    }
  };

  $('#customer_print_header').wysihtml5({
    locale: getLocaleFromCurrentLocale(),
    toolbar: {
      link: false,
      image: false,
      blockquote: false,
      size: 'sm',
      fa: true
    }
  });

  const smsCharacterCount = function() {
    var count = ($('#customer_sms_template').val() || $('#customer_sms_template').attr('placeholder')).length;
    var color = count > 160 ? 'red' : count > 140 ? 'darkorange' : 'black';
    $('#sms_character_count').html('<span style="color: ' + color + '">' + I18n.t('customers.form.sms_character_count', {c: count}) + '</span>');
  };
  const smsDriverCharacterCount = function() {
    var count = ($('#customer_sms_driver_template').val() || $('#customer_sms_driver_template').attr('placeholder')).length;
    var color = count > 160 ? 'red' : count > 140 ? 'darkorange' : 'black';
    $('#sms_driver_character_count').html('<span style="color: ' + color + '">' + I18n.t('customers.form.sms_character_count', {c: count}) + '</span>');
  };

  if ($('#customer_sms_template').length) {
    smsCharacterCount();
    $('#customer_sms_template').on('keyup', smsCharacterCount);
  }
  if ($('#customer_sms_driver_template').length) {
    smsDriverCharacterCount();
    $('#customer_sms_driver_template').on('keyup', smsDriverCharacterCount);
  }

  routerOptionsSelect('#customer_router', params);

  routersAllowedForProfile(params);
  $('#customer_profile_id').on('change', function() {
    routersAllowedForProfile(params);
    if (params['validate_layer'] === true) layersAllowedForProfile(params);
  });
  $('#customer_router').on('change', function() {
    removeRouterWarning();
  });
  $('#customer_layer_id').on('change', function() {
    removeLayerWarning();
  });

  // Delete multiple vehicles
  var requestPending = false;
  $("#delete-action").click(function() {
      if (confirm(I18n.t('all.verb.destroy_confirm')) && !requestPending) {
          requestPending = true;
          let vehicleIds = $.map($('table tbody :checkbox:checked').closest('tr'), function(val) {
              return $(val).find('input').attr('id');
          });
          $.ajax({
              type: "delete",
              url: '/api/0.1/vehicles?' + $.param({
                  ids: vehicleIds.join(',')
              }),
              beforeSend: beforeSendWaiting,
              success: function() {
                  $.map($('table tbody :checkbox:checked').closest('tr'), function(row) {
                      $(row).remove();
                  });
                  notice(I18n.t('customers.delete_multiple_vehicles.success'))
              },
              complete: function() {
                  requestPending = false;

                  completeWaiting();
              },
              error: ajaxError
          });
      }
  });

  $("#customer_enable_optimization_soft_upper_bound_button").change(function(e) {
    $("#optimization_soft_upper_bound").toggleClass('d-none');
  });
  
};

var routersAllowedForProfile = function(params) {
  var routersModesByProfile = JSON.parse(params.routers_modes_by_profile);
  var profileId = $('#customer_profile_id').val();
  if (profileId === '' || profileId === undefined) return;
  var routersModesAuthorized = routersModesByProfile[profileId];
  var routerOptions = $('#customer_router option');
  var e = document.getElementById('customer_router');
  var selectedRouter = e.options[e.selectedIndex].value;

  for (var i = 0, optionsLength = routerOptions.length; i < optionsLength; i++) {
    hideOrDisplayRouterMode(routersModesAuthorized, routerOptions[i].value, i);
  }

  if (routersModesAuthorized.indexOf(selectedRouter) !== -1) {
    removeRouterWarning();
  } else {
    displayRouterWarning();
  }
};

var hideOrDisplayRouterMode = function(routersModesAuthorized, optionEvaluated, key) {
  routersModesAuthorized = routersModesAuthorized || [];
  if (routersModesAuthorized.indexOf(optionEvaluated) !== -1) {
    $('#customer_router option').eq(key).removeClass('hidden');
  } else {
    $('#customer_router option').eq(key).addClass('hidden');
  }
};

var removeRouterWarning = function() {
  $("#customer_router_input").removeClass('has-warning');
  $(".router-unauthorized").addClass('hidden');
};

var displayRouterWarning = function() {
  $("#customer_router_input").addClass('has-warning');
  $(".router-unauthorized").removeClass('hidden');
};

var layersAllowedForProfile = function(params) {
  var layersByProfile = JSON.parse(params.layers_by_profile);
  var profileId = $('#customer_profile_id').val();
  if (profileId == '' || profileId === undefined) return;
  var layersAuthorized = layersByProfile[profileId];
  var layerOptions = $('#customer_layer_id option');
  var e = document.getElementById('customer_layer_id');
  var selectedLayer = e.options[e.selectedIndex].value;

  for (var i = 0, optionsLength = layerOptions.length; i < optionsLength; i++) {
    hideOrDisplayLayer(layersAuthorized, layerOptions[i].value, i);
  }

  if (layersAuthorized.indexOf(parseInt(selectedLayer)) !== -1) {
    removeLayerWarning();
  } else {
    displayLayerWarning();
  }
};

var hideOrDisplayLayer = function(layersAuthorized, optionEvaluated, key) {
  layersAuthorized = layersAuthorized || [];
  if (layersAuthorized.indexOf(parseInt(optionEvaluated)) !== -1) {
    $('#customer_layer_id option').eq(key).removeClass('hidden');
  } else {
    $('#customer_layer_id option').eq(key).addClass('hidden');
  }
};

var removeLayerWarning = function() {
  $("#customer_layer_id_input").removeClass('has-warning');
  $(".layer-unauthorized").addClass('hidden');
};

var displayLayerWarning = function() {
  $("#customer_layer_id_input").addClass('has-warning');
  $(".layer-unauthorized").removeClass('hidden');
};

const devicesObserveCustomer = (function () {
  var FLEET = 'fleet';
  function _devicesInitCustomer(base_name, config, params) {
    var requests = [];

    function clearCallback() {
      $('.' + config.name + '-api-sync').attr('disabled', 'disabled');
      $('#' + config.name + '_container').removeClass('panel-success panel-danger').addClass('panel-default');
    }

    function successCallback() {
      $('.' + config.name + '-api-sync').removeAttr('disabled');
      $('#' + config.name + '_container').removeClass('panel-default panel-danger').addClass('panel-success');

      if (config.name == FLEET) {
        $('#create-customer-device').attr('disabled', true);
        $('#create-user-device').attr('disabled', false);
      }
    }

    // maybe need rework on this one - WARNING -
    function errorCallback(apiError) {
      stickyError(apiError);
      $('.' + config.name + '-api-sync').attr('disabled', 'disabled');
      $('#' + config.name + '_container').removeClass('panel-default panel-success').addClass('panel-danger');

      if (config.name == FLEET) {
        $('#create-customer-device').attr('disabled', false);
        $('#create-user-device').attr('disabled', true);
      }
    }

    function _userCredential() {
      var hash = {};
      $.each(config.forms.settings, function (key) {
        hash[key] = $('#' + base_name + '_' + config.name + '_' + key).val() || void(0);
        if (key == 'password' && hash[key] == params.default_password)
          hash[key] = void(0);
      });
      return hash;
    }

    function _allFieldsFilled() {
      var isNotEmpty = true;
      var inputs = $('input[type="text"], input[type="password"]', '#' + config.name + '_container');
      inputs.each(function () {
        if ($(this).val() === '') {
          isNotEmpty = false;
        }
      });
      return !!(inputs.length && isNotEmpty);
    }

    function _ajaxCall(all) {
      $.when($(requests)).done(function () {
        if (!_allFieldsFilled()) return;
        requests.push($.ajax({
          url: '/api/0.1/devices/' + config.name + '/auth/' + params.customer_id + '.json',
          data: (all) ? _userCredential() : $.extend(_userCredential(), {
            check_only: 1
          }),
          dataType: 'json',
          beforeSend: function (jqXHR, settings) {
            if (!all) hideNotices();
            beforeSendWaiting();
          },
          complete: completeWaiting,
          success: function(data) {
            (data && data.error) ? errorCallback(data.error) : successCallback();
          },
          error: function(jqXHR, textStatus, error) {
            errorCallback(jqXHR.status === 400 && textStatus === 'error' ? I18n.t('customers.form.devices.sync.no_credentials') : textStatus);
          }
        }));
      });
    }

    // Check Credentials Without Before / Complete Callbacks ----- TRANSLATE IN ERROR CALL ISN'T SET
    function checkCredentials() {
      if (!_allFieldsFilled()) return;
      _ajaxCall(true);
    }

    // Check Credentials: Observe User Events with Delay
    const _observe = function () {
      var timeout_id;

      // Anonymous function handle setTimeout()
      var checkCredentialsWithDelay = function () {
        if (timeout_id) clearTimeout(timeout_id);
        timeout_id = setTimeout(function() { _ajaxCall(false); }, 750);
      };

      $("#" + config.name + "_container").find("input").on('keyup', function() {
        clearCallback();
        checkCredentialsWithDelay();
      });
    };

    /* Password Inputs: set fake password  (input view fake) */
    if ("password" in config) {
      var password_field = '#' + [base_name, config.name, "password"].join('_');
      if ($(password_field).val() === '') {
        $(password_field).val(params.default_password);
      }
    }

    // Sync
    $('.' + config.name + '-api-sync').on('click', function() {
      if (confirm(I18n.t('customers.form.devices.sync.confirm'))) {
        $.ajax({
          url: '/api/0.1/devices/' + config.name + '/sync.json',
          type: 'POST',
          data: $.extend(_userCredential(), {
            customer_id: params.customer_id
          }),
          beforeSend: function(jqXHR, settings) {
            beforeSendWaiting();
          },
          complete: function(jqXHR, textStatus) {
            completeWaiting();
          },
          success: function(data, textStatus, jqXHR) {
            alert(I18n.t('customers.form.devices.sync.complete'));
          }
        });
      }
    });

    // Check credential for current device config
    // Observe Widget if Customer has Service Enabled or Admin (New Customer)
    checkCredentials();
    _observe();
  }

  /* Chrome / FF, Prevent Sending Default Password
     The browsers would ask to remember it. */
  (function () {
    $('form.clear-passwords').on('submit', function (e) {
      $.each($(e.target).find('input[type=\'password\']'), function (i, element) {
        if ($(element).val() === params.default_password) {
          $(element).val('');
        }
      });
      return true;
    });
  })();

  const initialize = function (params) {
    $.each(params['devices'], function (deviceName, config) {
      config.name = deviceName;
      _devicesInitCustomer('customer_devices', config, params);
    });

    var requestCompleted = function(data) {
      if (data.error) {
        stickyError(data.error);
        return;
      }

      data.forEach(function(driver, index) {
        var msg = I18n.t((driver.updated) ? 'customers.form.devices.fleet.drivers_updated' : 'customers.form.devices.fleet.drivers_created');
        var email = (driver.updated) ? driver.email : driver.email + ' : ' + driver.password;
        notice(msg + "\r\n" + email);
      });
    };

    // Create company with mobile users for each vehicle with email
    $('#create-customer-device').on('click', function(event) {
      event.preventDefault();
      $('#create-customer-device').attr('disabled', true);

      $.ajax({
        type: 'PATCH',
        url: '/api/0.1/devices/fleet/create_company.json',
        data: {
          customer_id: params.customer_id
        },
        dataType: 'json',
        beforeSend: beforeSendWaiting,
        success: function(data) {
          $('#create-customer-device').attr('disabled', false);

          if (data.error) {
            requestCompleted(data);
            return;
          }

          requestCompleted(data.drivers);
          $('#customer_devices_fleet_user').val(data.email);
          $('#customer_devices_fleet_api_key').val(data.api_key);
          $('#fleet_container').removeClass('panel-default panel-danger').addClass('panel-success');
          $('#create-customer-device').attr('disabled', true);
          $('#create-user-device').attr('disabled', false);
        },
        error: function(error) {
          $('#create-customer-device').attr('disabled', false);
          stickyError(error.statusText + ' : ' + error.responseJSON.message);
        },
        complete: completeWaiting
      });
    });

    // Create mobile users for each vehicle with user
    $('#create-user-device').on('click', function(event) {
      event.preventDefault();
      $('#create-user-device').attr('disabled', true);

      $.ajax({
        type: 'PATCH',
        url: '/api/0.1/devices/fleet/create_or_update_drivers.json',
        data: {
          customer_id: params.customer_id
        },
        dataType: 'json',
        beforeSend: beforeSendWaiting,
        success: function(data) {
          $('#create-user-device').attr('disabled', false);
          requestCompleted(data);
        },
        error: function(error) {
          $('#create-user-device').attr('disabled', false);
          stickyError(error.statusText);
        },
        complete: completeWaiting
      });
    });
  };

  return {init: initialize};
})();



Paloma.controller('Customers', {
  index: function () {
    customers_index(this.params);
  },
  new: function () {
    customers_edit(this.params);
  },
  create: function () {
    customers_edit(this.params);
  },
  edit: function () {
    customers_edit(this.params);
  },
  update: function () {
    customers_edit(this.params);
  },
  import: function() {
    customers_edit(this.params);
  }
});
