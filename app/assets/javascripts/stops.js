'use strict';

export const stops_edit = function(params) {
  $('#radiobtn a').on('click', function(){
    var selected = $(this).data('title');
    var toggled = $(this).data('toggle');
    $(this).closest('.input-group').find('#'+toggled).prop('value', selected);
    $(this).closest('.input-group').find('#'+toggled+'_updated_at').prop('value', new Date().toUTCString());


    $('a[data-toggle="'+toggled+'"]').not('[data-title="'+selected+'"]').removeClass('active');
    $('a[data-toggle="'+toggled+'"][data-title="'+selected+'"]').addClass('active');

    var match = $(this).closest('.panel').find('#label-index').attr("class").match(new RegExp('label-[a-z]*'));
    $(this).closest('.panel').find('#label-index').removeClass(match.shift())
                     .addClass('label-'+selected);
    var match = $(this).closest('.panel').find('.panel-heading').attr("class").match(new RegExp('panel-heading-[a-z]*'));
    $(this).closest('.panel').find('.panel-heading').removeClass(match.shift())
                     .addClass('panel-heading-'+selected);
    submitForm($(this));
  });

  function submitForm(current_context) {
    current_context.closest('form').submit();
  }
};
