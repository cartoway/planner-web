'use strict';

import { beforeSendWaiting, completeWaiting, ajaxError } from '../../assets/javascripts/ajax';

const stops_edit = function(params) {
  $('#radiobtn a').on('click', function(){
    var sel = $(this).data('title');
    var tog = $(this).data('toggle');
    $('#'+tog).prop('value', sel);

    $('a[data-toggle="'+tog+'"]').not('[data-title="'+sel+'"]').removeClass('active');
    $('a[data-toggle="'+tog+'"][data-title="'+sel+'"]').addClass('active');
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
    console.log(position);
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
