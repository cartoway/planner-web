'use strict';

import { beforeSendWaiting, completeWaiting, ajaxError } from '../../assets/javascripts/ajax';
import { stops_edit } from '../../assets/javascripts/stops';

const tracking = function(params) {
  let positionInterval = null;

  $('#location-switch').on('change', function(){
    setTracking($(this).prop('checked'));
  });

  function setTracking(tracking_value) {
    sessionStorage['tracking_value'] = tracking_value;
    if (tracking_value == 'false') {
      stopInterval();
    } else {
      startInterval();
    }
  }

  function initTracking() {
    var tracking_value = sessionStorage['tracking_value'];
    if (tracking_value === 'false') {
      $('#location-switch').attr('checked', false);
    } else {
      startInterval();
    }
  }

  function getPosition() {
    if (sessionStorage['tracking_value'] !== 'false') {
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(sendPosition, handleError);
      } else {
        alert("Geolocation is not supported by this browser.");
      }
    }
  }

  function sendPosition(position) {
    var coords = position.coords;
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
    switch(error.code) {
      case error.PERMISSION_DENIED:
        alert("User denied the request for Geolocation.");
        break;
      default:
        alert("An error occurred: " + error.message);
    }
  }

  function startInterval() {
    if (positionInterval === null) {
      positionInterval = setInterval(getPosition, 60 * 1000);
    }
  }

  function stopInterval() {
    if (intervalId !== null) {
      clearInterval(positionInterval);
      positionInterval = null;
    }
  }
  getPosition();

  initTracking();
};

Paloma.controller('Stops', {
  edit: function() {
    tracking(this.params);
    stops_edit(this.params);
  }
});

Paloma.controller('Routes', {
  mobile: function() {
    tracking(this.params);
  }
});
