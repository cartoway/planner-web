'use strict';

export const stops_edit = function(params) {
  $.find('.no-toggle').forEach(function(button) {
    button.addEventListener('click', function(e) {
      e.stopPropagation();
    });
  })
  $(document).on('click', '.radiobtn a, #quick-status', function() {
    var selected = $(this).data('title');
    changeStatuses($(this), selected);
  });

  $('.custom_field').each(function() {
    var element = $(this).find('input, select, textarea');
    element.on('change', function() {
      var panel = element.closest('.panel');
      submitForm(panel);
    });
  })

  function changeStatuses(element, selected) {
    var panel = $(element).closest('.panel');
    var toggled = $(element).data('toggle');
    panel.find('.input-group').find('#'+toggled).prop('value', selected);
    panel.find('.input-group').find('#'+toggled+'_updated_at').prop('value', new Date().toUTCString());

    panel.find('.radiobtn a[data-toggle="'+toggled+'"]').not('[data-title="'+selected+'"]').removeClass('active');
    panel.find('.radiobtn a[data-toggle="'+toggled+'"][data-title="'+selected+'"]').addClass('active');

    var label = panel.find('#label-index');
    var labelClasses = label.attr("class") || "";
    var labelMatch = labelClasses.match(/label-[a-z_]*$/);
    if (labelMatch) {
      label.removeClass(labelMatch[0]);
    }
    label.addClass('label-' + selected);

    var heading = panel.find('.panel-heading');
    var headingClasses = heading.attr("class") || "";
    var headingMatch = headingClasses.match(/panel-heading-[a-z_]*$/);
    if (headingMatch) {
      heading.removeClass(headingMatch[0]);
    }
    heading.addClass('panel-heading-' + selected);

    var stopType = panel.data('stop-type');

    // Quick "delivered" shortcut only makes sense for StopVisits
    if (stopType === 'visit' &&selected == 'intransit') {
      var next_status = 'delivered';
      panel.find('#quick-status').removeClass('d-none');
      panel.find('#quick-status').data('title', next_status);
      panel.find('#quick-status-text').text(I18n.t("plannings.edit.stop_status.delivered"));
    } else {
      panel.find('#quick-status').addClass('d-none');
    }
    submitForm(panel);
  }

  function storeStopUpdate(url, formData) {
    const updateData = {
      id: Date.now(),
      url: url,
      formData: formData
    };

    $('#mobile-sync-pending').removeClass('d-none');

    if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({
        type: 'STORE_STOP',
        payload: updateData
      });
    } else {
      localStorage.setItem(`stop_update_${updateData.id}`, JSON.stringify(updateData));
    }
  }

  function submitForm(current_context) {
    const form = current_context.find('form')[0];
    const formData = new FormData(form);
    const url = current_context.find('form').attr('action');

    // Only append stop-specific field for stop forms (not for route driver_update forms)
    if (url.indexOf('/stops/') !== -1) {
      formData.append('stop[status_updated_at]', new Date().toISOString());
    }

    const formObject = {};
    formData.forEach((value, key) => {
      formObject[key] = value;
    });

    if (!navigator.onLine) {
      storeStopUpdate(url, formObject);
      return;
    }

    $.ajax({
      type: 'PATCH',
      url: url,
      data: formData,
      processData: false,
      contentType: false,
      error: () => storeStopUpdate(url, formObject)
    });
  }
};
