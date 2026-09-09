'use strict';

const parseTimeToSeconds = function(value) {
  if (!value) return null;
  var parts = value.split(':').map(function(part) { return Number(part); });
  if (parts.some(function(part) { return isNaN(part); })) return null;
  return (parts[0] || 0) * 3600 + (parts[1] || 0) * 60 + (parts[2] || 0);
};

const clearTimeField = function($field) {
  $field.val('');
  if ($field.data('timeEntry')) {
    $field.timeEntry('setTime', null);
  }
};

const inheritedSeconds = function($field) {
  var seconds = Number($field.attr('data-inherited-seconds'));
  return seconds > 0 ? seconds : 0;
};

export const initRestTypeFields = function(prefix) {
  var $form = $('form');
  var restMode = 'input[name="' + prefix + '[rest_mode]"]';
  var $duration = $('#' + prefix + '_rest_duration');
  var $lapse = $('#' + prefix + '_rest_lapse');
  var $start = $('#' + prefix + '_rest_start');
  var $stop = $('#' + prefix + '_rest_stop');
  var $startDay = $('#' + prefix + '_rest_start_day');
  var $stopDay = $('#' + prefix + '_rest_stop_day');
  var $store = $('#' + prefix + '_store_rest_id');
  var $windowRow = $('#' + prefix + '_rest_start_stop_input');
  var $lapseRow = $('#' + prefix + '_rest_lapse_input');

  // timeEntry defaultTime fills empty inputs with 00:00; keep unset regulatory fields blank.
  [$duration, $lapse].forEach(function($field) {
    if ($field.length && !$field.attr('value')) {
      clearTimeField($field);
    }
  });

  var applyMode = function(userChanged) {
    var regulatory = $(restMode + ':checked').val() === 'regulatory';
    $windowRow.toggle(!regulatory);
    $lapseRow.toggle(regulatory);
    $form.find('.rest-store-select').toggle(!regulatory);
    $duration.toggleClass('width_1_2', !regulatory);
    $form.find('.rest-duration-label-window').toggle(!regulatory);
    $form.find('.rest-duration-label-regulatory').toggle(regulatory);
    $form.find('.rest-duration-help-window').toggle(!regulatory);
    if (regulatory) {
      clearTimeField($start);
      clearTimeField($stop);
      $startDay.val('');
      $stopDay.val('');
      $store.val('');
      if (userChanged) {
        clearTimeField($duration);
        clearTimeField($lapse);
      }
    } else {
      clearTimeField($lapse);
    }
  };

  $(restMode).on('change', function() { applyMode(true); });

  $form.on('submit', function(e) {
    if ($(restMode + ':checked').val() !== 'regulatory') return true;

    applyMode();
    var duration = parseTimeToSeconds($duration.val()) || inheritedSeconds($duration);
    var lapse = parseTimeToSeconds($lapse.val()) || inheritedSeconds($lapse);
    if (!duration) {
      if (typeof stickyError === 'function') {
        stickyError(I18n.t('vehicle_usages.form.rest_type.duration_must_be_filled'));
      }
      e.preventDefault();
      return false;
    }
    if (!lapse) {
      if (typeof stickyError === 'function') {
        stickyError(I18n.t('vehicle_usages.form.rest_type.lapse_must_be_filled'));
      }
      e.preventDefault();
      return false;
    }
    if (duration >= lapse) {
      if (typeof stickyError === 'function') {
        stickyError(I18n.t('vehicle_usages.form.rest_type.duration_must_be_smaller'));
      }
      e.preventDefault();
      return false;
    }
    return true;
  });

  applyMode();
};
