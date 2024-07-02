'use strict';

export const stops_edit = function(params) {
  $('#radiobtn a, #quick-status').on('click', function() {
    var selected = $(this).data('title');
    changeStatuses($(this), selected);
  });

  function changeStatuses(element, selected) {
    var panel = $(element).closest('.panel');
    var toggled = $(element).data('toggle');
    panel.find('.input-group').find('#'+toggled).prop('value', selected);
    panel.find('.input-group').find('#'+toggled+'_updated_at').prop('value', new Date().toUTCString());


    panel.find('#radiobtn a[data-toggle="'+toggled+'"]').not('[data-title="'+selected+'"]').removeClass('active');
    panel.find('#radiobtn a[data-toggle="'+toggled+'"][data-title="'+selected+'"]').addClass('active');

    var match = panel.find('#label-index').attr("class").match(new RegExp('label-([a-z]*)'));
    panel.find('#label-index').removeClass(match.shift())
                     .addClass('label-'+selected);
    var match = panel.find('.panel-heading').attr("class").match(new RegExp('panel-heading-[a-z]*'));
    panel.find('.panel-heading').removeClass(match.shift())
                     .addClass('panel-heading-'+selected);

    var next_status;
    if(selected == 'intransit') {
      next_status = 'delivered';
      panel.find('#quick-status').removeClass('d-none');
      panel.find('#quick-status').data('title', next_status);
      panel.find('#quick-status-text').text(I18n.t("plannings.edit.stop_status." + next_status));
    } else {
      panel.find('#quick-status').addClass('d-none');
    }
    submitForm(panel);
  }

  function submitForm(current_context) {
    console.log(current_context.find('form'));
    current_context.find('form').submit();
  }
};
