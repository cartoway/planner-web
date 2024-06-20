'use strict';

import { beforeSendWaiting, completeWaiting, ajaxError } from '../../assets/javascripts/ajax';

const stops_edit = function(params) {
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


  function getPosition() {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(sendPosition, handleError);
    } else {
      alert("Geolocation is not supported by this browser.");
    }
  }

  function sendPosition(position) {
    var coords = position.coords;
    console.log(coords);
    $.ajax({
      type: 'PATCH',
      url: '/routes/' + params.route_id +'/update_position',
      data: JSON.stringify(coords),
      contentType : 'application/json',
      beforeSend: function(jqXHR, settings) {
        beforeSendWaiting();
      },
      complete: function(jqXHR, textStatus) {
        completeWaiting();
      }
    });
  }

  function handleError(error) {
    console.log(error);
    switch(error.code) {
      case error.PERMISSION_DENIED:
        alert("User denied the request for Geolocation.");
        break;
      default:
        alert("An error occurred: " + error.message);
    }
  }

  getPosition();
  setInterval(getPosition, 5 * 60 * 1000);
};

Paloma.controller('Stops', {
  edit: function() {
    stops_edit(this.params);
  }
});
