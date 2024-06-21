'use strict';

export const stops_edit = function(params) {
  $('#radiobtn a').on('click', function(){
    var selected = $(this).data('title');
    var toggled = $(this).data('toggle');
    $('#'+toggled).prop('value', selected);

    $('a[data-toggle="'+toggled+'"]').not('[data-title="'+selected+'"]').removeClass('active');
    $('a[data-toggle="'+toggled+'"][data-title="'+selected+'"]').addClass('active');

    var match = $('#label-index').attr("class").match(new RegExp('label-[a-z]*'));
    $('#label-index').removeClass(match.shift())
                     .addClass('label-'+selected);
    submitForm($(this));
  });

  function submitForm(current_context) {
    current_context.closest('form').submit();
  }
};
