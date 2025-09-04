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
export const progressDialog = function(delayedJob, dialog, url, callback, options) {
  if (delayedJob !== undefined) {
    var timeout = 200;
    var duration;

    dialog.modal(modal_options());
    freezeProgressDialog(dialog);
    var progress = delayedJob.progress;

    updateOptimizationDetails(dialog, progress);
    $(".progress-bar", dialog).each(function(i, e) {
      // hide or show dialog-progress class
      if (!progress || !progress['completed'] && (!progress['status'] || progress['status'] == 'queued')) {
        $(e).parent().parent().hide();
      } else {
        $(e).parent().parent().show();
        fieldBarProgression(dialog, delayedJob, progress, e, i);
      }
    });

    if ((!progress || !progress['completed'] && progress['status'] != 'working') && delayedJob.attempts == 0) {
      $(".dialog-inqueue", dialog).show();
    } else {
      $(".dialog-inqueue", dialog).hide();
    }

    if (delayedJob.attempts > 0 && progress && progress['failed']) {
      options && options.error && options.error();
      $(".dialog-no-solution", dialog).show();
      $(".dialog-progress", dialog).hide();
      unfreezeProgressDialog(dialog, delayedJob, url, callback); // url should not contain dispatch_params_delayed_job

      return false;
    }

    if (delayedJob.attempts) {
      $(".dialog-attempts-number", dialog).html(delayedJob.attempts);
      $(".dialog-attempts", dialog).show();
    } else {
      $(".dialog-attempts", dialog).hide();
    }

    if (delayedJob.error) {
      options && options.error && options.error();
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

export const fieldBarProgression = function(dialog, delayedJob, progress, element, index) {
  var bar_value = 0;
  switch (index) {
    case 0:
      if (progress['first_progression']) {
        bar_value = progress['completed'] ? 100 : progress['first_progression'];
      }
      break;
    case 1:
      if (progress['second_progression']) {
        bar_value = progress['completed'] ? 100 : progress['second_progression'];
      }
      break;
    case 2:
      bar_value = progress['completed'] ? -1 : 0
      break;
  }
  if (Number(bar_value) == -1) {
    $(element).parent().addClass("active");
    $(element).css({
      transition: 'none',
      width: '100%'
    });
  } else if (Number(bar_value) >= 0 || Number(bar_value) <= 100) {
    $(element).parent().removeClass("active");
    $(element).css({
      transition: 'linear 0.5s',
      width: "" + bar_value + "%"
    });
  } else if (progress['multipart']) {
    // optimization or geocoding current/total
    var currentSteps = progress[i].split('/');
    if (currentSteps[0] > 0) {
    }
    $(element).parent().removeClass("active");
    $(element).css("transition", "linear 0.5s");
    $(element).css("width", "" + (100 * bar_value) + "%");
    $(element).html(progress[i]);
  } else {
    // optimization in ms
    var timeSpent = progress['elapsed'] || 0;
    if (timeSpent > 0) {
    }
    if (iteration != timeSpent[1] || $(".dialog-attempts-number", dialog).html() != delayedJob.attempts) {
      iteration = timeSpent[1];
      duration = parseInt(timeSpent[0]);
      if (duration > timeout) {
        $(element).parent().removeClass("active");
        $(element).css("transition", "linear " + ((duration - timeout) / 1000) + "s");
        $(element).css("width", "100%");
      } else {
        $(element).css('transition', 'none');
        $(element).css('width', '0%');
      }
    }
  }
}


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

let optimizationDetailsInitialized = false;
export const updateOptimizationDetails = function(dialog, progress) {
  const detailsContainer = $('#optimization-details', dialog);
  const collapseElement = $('#collapseSolverDetails', dialog);
  const toggleElement = $('.accordion-toggle', dialog);

  if (!progress || !detailsContainer.length) {
    return;
  }

  const hasSolvers = progress.solvers && Array.isArray(progress.solvers) && progress.solvers.length > 0;
  const hasSkippedServices = progress.skipped_services && Array.isArray(progress.skipped_services) && progress.skipped_services.length > 0;

  if (hasSolvers || hasSkippedServices) {
    if (!detailsContainer.is(':visible')) {
      detailsContainer.show();
    }

    if (!optimizationDetailsInitialized) {
      if (hasSolvers) {
        const solversList = $('#solvers-list', dialog);

        const solverCounts = {};
        progress.solvers.forEach(solver => {
          solverCounts[solver] = (solverCounts[solver] || 0) + 1;
        });

        const solversHtml = '<h5>' + mustache_i18n()('plannings.edit.dialog.optimizer.solvers') + '</h5><ul>' +
          Object.entries(solverCounts).map(([solver, count]) =>
            `<li><strong>${solver}</strong> (x${count})</li>`
          ).join('') + '</ul>';

        solversList.html(solversHtml);
      }

      if (hasSkippedServices) {
        const skippedList = $('#skipped-services-list', dialog);

        const solverGroups = {};
        progress.skipped_services.forEach(item => {
          if (item.solver && item.reasons && Array.isArray(item.reasons)) {
            if (!solverGroups[item.solver]) {
              solverGroups[item.solver] = [];
            }
            solverGroups[item.solver].push(...item.reasons);
          }
        });

        const skippedHtml = '<h5>' + mustache_i18n()('plannings.edit.dialog.optimizer.skipped_services') + '</h5><ul class="list-unstyled">' +
          Object.entries(solverGroups).map(([solver, allReasons]) => {
            const reasonCounts = {};
            allReasons.forEach(reason => {
              reasonCounts[reason] = (reasonCounts[reason] || 0) + 1;
            });

            return `<li><strong>${solver}:</strong><ul class="ms-3">` +
              Object.entries(reasonCounts).map(([reason, count]) => {
                const translatedReason = getTranslatedReason(reason);
                return `<li>${translatedReason}${count > 1 ? ` (x${count})` : ''}</li>`;
              }).join('') + '</ul></li>';
          }).join('') + '</ul>';

        skippedList.html(skippedHtml);
      }

      toggleElement.off('click.collapse');
      toggleElement.on('click.collapse', function(e) {
        e.preventDefault();

        if (collapseElement.hasClass('in')) {
          collapseElement.removeClass('in').addClass('collapse');
          $(this).removeClass('collapsed');
          $(this).find('i').removeClass('fa-chevron-up').addClass('fa-chevron-down');
        } else {
          collapseElement.removeClass('collapse').addClass('in');
          $(this).addClass('collapsed');
          $(this).find('i').removeClass('fa-chevron-down').addClass('fa-chevron-up');
        }
      });

      optimizationDetailsInitialized = true;
    }
  } else {
    detailsContainer.hide();
    optimizationDetailsInitialized = false;
  }
};

const getTranslatedReason = function(reason) {
  const translationKey = `plannings.edit.dialog.optimizer.skipped_reasons.${reason}`;
  return mustache_i18n()(translationKey);
};
