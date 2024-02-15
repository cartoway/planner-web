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

import { modal_options } from './scaffolds';

let ajaxWaitingGlobal = 0;
let progressDialogTimerId;

export const beforeSendWaiting = function() {
  if (ajaxWaitingGlobal === 0) {
    $('body').addClass('ajax_waiting');
  }
  ajaxWaitingGlobal++;
};

export const completeWaiting = function() {
  ajaxWaitingGlobal--;
  if (ajaxWaitingGlobal === 0) {
    $('body').removeClass('ajax_waiting');
  }
};

export const completeAjaxMap = function() {
  completeWaiting();
};

export const ajaxError = function(request, status, error) {
  var otext = request.responseText;
  var text;
  try {
    text = "";
    $.each($.parseJSON(otext), function(i, e) {
      text += " " + e;
    });
  } catch (e) {
    text = otext;
  }
  if (!text) {
    text = status;
  }
  if (request.readyState != 0) {
    stickyError(text);
  }
};

export const mustache_i18n = function() {
  return function(text) {
    return I18n.t(text);
  };
};

let needCbAfterDeletingJob = true;
let progressDialogFrozen = false;
export const freezeProgressDialog = function(dialog) {
  if (!progressDialogFrozen) {
    dialog.find('[data-dismiss]').hide();
    dialog.off('hidden.bs.modal'); // important to avoid canceling old jobs
    dialog.off('keyup');
    beforeSendWaiting();
    progressDialogFrozen = true;
  }
};

export const unfreezeProgressDialog = function(dialog, delayedJob, url, callback) {
  dialog.find('[data-dismiss]').show();
  dialog.data()['bs.modal'].options.backdrop = false;
  dialog.on('hidden.bs.modal', function() {
    // delayedJob could contain neither customer_id nor id in case of server error...
    $.ajax({
      type: 'DELETE',
      url: '/api/0.1/customers/' + delayedJob.customer_id + '/job/' + delayedJob.id + '.json',
      success: function() {
        if (needCbAfterDeletingJob) $.ajax({
          type: 'GET',
          url: url,
          beforeSend: beforeSendWaiting,
          success: callback,
          complete: completeAjaxMap,
          error: ajaxError
        });
      },
      error: ajaxError
    });
    dialog.off('keyup');
    // Reset dialog content
    $(".dialog-progress", dialog).show();
    $(".dialog-attempts", dialog).hide();
    $(".dialog-error", dialog).hide();
    $(".dialog-no-solution", dialog).hide();
    $(".progress-bar", dialog).css("width", "0%");
  });
  dialog.on('keyup', function(e) {
    if (e.keyCode == 27) {
      dialog.modal('hide');
    }
    if (e.keyCode == 13) {
      dialog.find('.btn-primary')[0].click();
    }
  });
  completeWaiting();
  progressDialogFrozen = false;
};

let iteration = undefined;
let isProgressing = false;
export const progressDialog = function(delayedJob, dialog, url, callback, options) {
  if (delayedJob !== undefined) {
    var timeout = 2000;
    var duration;

    dialog.modal(modal_options());
    freezeProgressDialog(dialog);

    isProgressing = false;
    var progress = delayedJob.progress && delayedJob.progress.split(';');
    $(".progress-bar", dialog).each(function(i, e) {
      // hide or show dialog-progress class
      if (typeof progress === "undefined" || progress === null || progress === '' || typeof progress[i] === "undefined" || progress[i] === '') {
        $(e).parent().parent().hide();
      } else {
        $(e).parent().parent().show();
      }

      if (!progress || typeof progress[i] === "undefined" || progress[i] === null || progress[i] === '') {
        // Inactive progress class
        $(e).parent().removeClass("active");
        $(e).css({
          transition: 'none',
          width: '0%'
        });
      } else if (progress[i] === 0 || progress[i] === '0') {
        isProgressing = true;
        $(e).parent().removeClass("active");
        $(e).css({
          transition: 'none',
          width: '0%'
        });
      } else if (progress[i] === 100 || progress[i] === '100') {
        isProgressing = true;
        $(e).parent().removeClass("active");
        $(e).css({
          transition: 'none',
          width: '100%'
        });
      } else if (progress[i] === -1 || progress[i] === '-1') {
        isProgressing = true;
        $(e).parent().addClass("active");
        $(e).css({
          transition: 'none',
          width: '100%'
        });
      } else if (progress[i].indexOf('ms') > -1) {
        // optimization in ms
        var timeSpent = progress[i].split('ms');
        if (timeSpent > 0) {
          isProgressing = true;
        }
        if (iteration != timeSpent[1] || $(".dialog-attempts-number", dialog).html() != delayedJob.attempts) {
          iteration = timeSpent[1];
          duration = parseInt(timeSpent[0]);
          if (duration > timeout) {
            $(e).parent().removeClass("active");
            $(e).css("transition", "linear " + ((duration - timeout) / 1000) + "s");
            $(e).css("width", "100%");
          } else {
            $(e).css('transition', 'none');
            $(e).css('width', '0%');
          }
        }
      } else if (progress[i].indexOf('/') > -1) {
        // optimization or geocoding current/total
        var currentSteps = progress[i].split('/');
        if (currentSteps[0] > 0) {
          isProgressing = true;
        }
        $(e).parent().removeClass("active");
        $(e).css("transition", "linear 0.5s");
        $(e).css("width", "" + (100 * currentSteps[0] / currentSteps[1]) + "%");
        $(e).html(progress[i]);
      } else {
        isProgressing = true;
        $(e).parent().removeClass("active");
        $(e).css("transition", "linear 2s");
        $(e).css("width", "" + progress[i] + "%");
      }
    });

    if (isProgressing || delayedJob.attempts > 0) {
      $(".dialog-inqueue", dialog).hide();
    } else {
      $(".dialog-inqueue", dialog).show();
    }

    if (delayedJob.attempts > 0 && delayedJob.progress === 'no_solution') {
      options && options.error && options.error();
      isProgressing = true;
      $(".dialog-no-solution", dialog).show();
      $(".dialog-progress", dialog).hide();
      unfreezeProgressDialog(dialog, delayedJob, url, callback); // url should not contain dispatch_params_delayed_job

      return false;
    }

    if (delayedJob.attempts) {
      isProgressing = true;
      $(".dialog-attempts-number", dialog).html(delayedJob.attempts);
      $(".dialog-attempts", dialog).show();
    } else {
      $(".dialog-attempts", dialog).hide();
    }

    if (delayedJob.error) {
      options && options.error && options.error();
      isProgressing = true;
      $(".dialog-progress", dialog).hide();
      $(".dialog-error", dialog).show();
      unfreezeProgressDialog(dialog, delayedJob, url, callback); // url should not contain dispatch_params_delayed_job
    } else {
      progressDialogTimerId = setTimeout(function() {
        $.ajax({
          method: 'GET',
          data: delayedJob.dispatch_params_delayed_job,
          url: url,
          success: function(data) {
            data.dispatch_params_delayed_job = delayedJob.dispatch_params_delayed_job;
            callback(data, options);
          },
          error: ajaxError
        });
      }, 200);

      $(document).on('page:before-change', function() {
        clearTimeout(progressDialogTimerId);
        $(document).off('page:before-change');
      });
    }

    return false;
  } else {
    // Called when job has ended or when delayedjob is not active
    needCbAfterDeletingJob = false;
    iteration = null;
    progressDialogFrozen = false;
    if (dialog.is(':visible')) {
      dialog.modal('hide');
      $(".progress-bar", dialog).css({
        transition: 'linear 0s',
        width: '0%'
      });
      completeWaiting(); // In case of success with delayedjob unfreezeProgressDialog is never called
    }
    options && options.success && options.success();

    return true;
  }
};


export const fake_select2 = function(selector, callback) {
  var fake_select2_replace = function(fake_select) {
    var select = fake_select.prev();
    fake_select.hide();
    select.show();
    callback(select);
    fake_select.off();
  };

  var fake_select2_click = function(e) {
    // On the first click on select2-look like div, initialize select2, remove the placeholder and resend the click
    var fake_select = $(this);
    e.stopPropagation();
    fake_select2_replace(fake_select);
    if (e.clientX && e.clientY) {
      $(document.elementFromPoint(e.clientX, e.clientY)).click();
    }
  };

  var fake_select2_key_event = function(e) {
    var fake_select = $(this).closest('.fake');
    e.stopPropagation();
    var parent = $(this).parent();
    fake_select2_replace(fake_select);
    var input = $('input', parent);
    input.focus();
    // var ee = jQuery.Event('keydown');
    // ee.which = e.which;
    // $('input', $(this)).trigger(ee);
  };

  selector.next()
    .on('click', fake_select2_click)
    .on('keydown', fake_select2_key_event);
};

export const phoneNumberCall = function(object, userCall) {
  object.numberHref   = userCall.replace("{TEL}", object.phone_number);
  object.numberTarget = (document.location.protocol === "http:") ? '_blank' : '_self';
};
