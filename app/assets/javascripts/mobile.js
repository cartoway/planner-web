'use strict';

import { stops_edit } from '../../assets/javascripts/stops';
import {
  beforeSendWaiting,
  ajaxError,
  completeWaiting,
} from '../../assets/javascripts/ajax';

const tracking = function(params) {
  let positionInterval = null;
  let messageListener;
  let stop_id;
  let pendingDataInterval = null;

  $(".route-select").on("click", ".send_to_route", function() {
    stop_id = $(this).data('stop-id');
    var url = this.href;
    $.ajax({
      type: 'PATCH',
      url: url,
      beforeSend: function() {
        addSpinner(stop_id);
        beforeSendWaiting();
      },
      complete: function() {
        completeWaiting();
      },
      success: function() {
        removeStop(stop_id);
      },
      error: ajaxError
    });
    return false;
  });

  function addSpinner(stop_id) {
    $('#heading-' + stop_id).closest('.panel').find('#transfer-label')
      .addClass('spinner-container row')
      .prepend('<div class="col-xs-1"><div class="spinner-border"></div></div>');
  }

  function removeStop(stop_id) {
    $('#heading-' + stop_id).closest('.panel').remove();
  }

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

  function initServiceWorker() {
    if (!('serviceWorker' in navigator)) {
      return;
    }

    if (messageListener) {
      navigator.serviceWorker.removeEventListener('message', messageListener);
    }

    messageListener = event => {
      if (event.data.type === 'POSITION_SYNCED') {
        $('#mobile-sync-pending').fadeOut(500, function() {
          $(this).addClass('d-none').show();
        });
        startInterval();
      }

      if (event.data.type === 'STOP_SYNCED') {
        $('#mobile-sync-pending').fadeOut(500, function() {
          $(this).addClass('d-none').show();
        });
      }

      if (event.data.type === 'SYNC_ERROR') {
        $('#mobile-sync-failed').removeClass('d-none');
        setTimeout(() => {
          $('#mobile-sync-failed').fadeOut(500, function() {
            $(this).addClass('d-none').show();
          });
        }, 3000);
      }

      if (event.data.type === 'STORE_STOPS') {
        event.data.data.forEach(stop => {
          localStorage.setItem(`stop_update_${stop.id}`, JSON.stringify(stop));
        });
      }

      if (event.data.type === 'STORE_POSITIONS') {
        event.data.data.forEach(position => {
          localStorage.setItem(`position_${position.id}`, JSON.stringify(position));
        });
      }

      if (event.data.type === 'GET_PENDING_DATA') {
        const data = {
          positions: [],
          stops: []
        };

        for (let i = 0; i < localStorage.length; i++) {
          const key = localStorage.key(i);
          if (key.startsWith('position_')) {
            const position = JSON.parse(localStorage.getItem(key));
            data.positions.push(position);
            localStorage.removeItem(key);
          } else if (key.startsWith('stop_update_')) {
            const stop = JSON.parse(localStorage.getItem(key));
            data.stops.push(stop);
            localStorage.removeItem(key);
          }
        }

        if (data.stops.length === 0) {
          $('#mobile-sync-pending').addClass('d-none');
        }

        event.source.postMessage({
          type: 'PENDING_DATA',
          data: data
        });
      }
    };

    navigator.serviceWorker.addEventListener('message', messageListener);

    const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
    navigator.serviceWorker.register('/service-worker.js', {
      scope: '/'
    })
    .then(registration => {
      if (registration.waiting) {
        registration.waiting.postMessage({type: 'SKIP_WAITING'});
      }

      registration.addEventListener('activate', () => {
        if (registration.active) {
          registration.active.postMessage({
            type: 'SET_CSRF_TOKEN',
            token: token
          });
          checkPendingData();
        }
      });

      if ('SyncManager' in window) {
        window.syncManagerAvailable = true;
      } else {
        window.syncManagerAvailable = false;
      }
    })
    .catch(error => {
      window.syncManagerAvailable = false;
    });
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
        alert(I18n.t('errors.mobile.unsupported_geolocation'));
        clearInterval(positionInterval);
      }
    }
  }

  function sendPosition(position) {
    const coords = {
      accuracy: position.coords.accuracy,
      altitude: position.coords.altitude,
      altitudeAccuracy: position.coords.altitudeAccuracy,
      heading: position.coords.heading,
      latitude: position.coords.latitude,
      longitude: position.coords.longitude,
      speed: position.coords.speed,
    };

    if (navigator.onLine) {
      $.ajax({
        type: 'PATCH',
        url: '/routes/' + params.route_id + '/update_position',
        data: JSON.stringify(coords),
        contentType: 'application/json',
        error: function(request, status, error) {
          storePosition(coords);
        }
      });
    } else {
      storePosition(coords);
      if ('serviceWorker' in navigator && 'SyncManager' in window) {
        navigator.serviceWorker.ready.then(registration => {
          registration.sync.register('sync-positions')
        });
      }
    }
  }

  function storePosition(coords) {
    const positionData = {
      id: Date.now(),
      routeId: params.route_id,
      coords: coords,
      timestamp: new Date().toISOString()
    };

    $('#mobile-sync-pending').removeClass('d-none');

    if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({
        type: 'STORE_POSITION',
        payload: positionData
      });
    } else {
      localStorage.setItem(`position_${positionData.id}`, JSON.stringify(positionData));
    }
  }

  function handleError(error) {
    switch(error.code) {
      case error.PERMISSION_DENIED:
        alert(I18n.t('errors.mobile.denied_geolocation'));
        clearInterval(positionInterval);
        break;
      case error.POSITION_UNAVAILABLE:
        alert(I18n.t('errors.mobile.position_unavailable'));
        clearInterval(positionInterval);
        break;
      default:
        alert(I18n.t('errors.mobile.default'));
        clearInterval(positionInterval);
    }
  }

  function startInterval() {
    if (positionInterval === null) {
      positionInterval = setInterval(getPosition, 60 * 1000);
    }
  }

  function stopInterval() {
    if (positionInterval !== null) {
      clearInterval(positionInterval);
      positionInterval = null;
    }
  }

  function checkPendingData() {
    if (navigator.onLine) {
      if ('serviceWorker' in navigator && 'SyncManager' in window) {
        if (navigator.serviceWorker.controller) {
          const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
          navigator.serviceWorker.controller.postMessage({
            type: 'SET_CSRF_TOKEN',
            token: token
          });
        }

        navigator.serviceWorker.ready.then(registration => {
          registration.sync.register('sync-positions');
          registration.sync.register('sync-stops');
        });
      } else {
        if (hasPendingData('position_')) {
          syncPositionsWithoutServiceWorker();
        }
        if (hasPendingData('stop_update_')) {
          syncStopsWithoutServiceWorker();
        }
      }
    }
  }

  function hasPendingData(prefix) {
    return Object.keys(localStorage).some(key => key.startsWith(prefix));
  }

  getPosition();
  initTracking();

  ['DOMContentLoaded', 'online', 'visibilitychange', 'networkchange'].forEach(event => {
    window.addEventListener(event, checkPendingData);
  });

  if (!('serviceWorker' in navigator && 'SyncManager' in window)) {
    pendingDataInterval = setInterval(checkPendingData, 30 * 1000);
  }

  function syncPositionsWithoutServiceWorker() {
    const positions = [];
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key.startsWith('position_')) {
        positions.push(JSON.parse(localStorage.getItem(key)));
      }
    }

    positions.forEach(position => {
      $.ajax({
        type: 'PATCH',
        url: '/routes/' + position.routeId + '/update_position',
        data: JSON.stringify(position.coords),
        contentType: 'application/json',
        success: function() {
          localStorage.removeItem(`position_${position.id}`);
          $('#mobile-sync-pending').addClass('d-none');
        },
        error: function(xhr) {
          if (xhr.status === 409) {
            localStorage.removeItem(`position_${position.id}`);
            $('#mobile-sync-pending').addClass('d-none');
          } else if ([404, 408, 502, 503, 504].includes(xhr.status)) {
            return;
          } else {
            localStorage.removeItem(`position_${position.id}`);
            $('#mobile-sync-failed').removeClass('d-none');
          }
        }
      });
    });
  }

  function syncStopsWithoutServiceWorker() {
    const updates = [];
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key.startsWith('stop_update_')) {
        updates.push(JSON.parse(localStorage.getItem(key)));
      }
    }

    updates.forEach(update => {
      const formData = new FormData();
      Object.keys(update.formData).forEach(key => {
        formData.append(key, update.formData[key]);
      });

      $.ajax({
        type: 'PATCH',
        url: update.url,
        data: formData,
        processData: false,
        contentType: false,
        success: function() {
          localStorage.removeItem(`stop_update_${update.id}`);
        $('#mobile-sync-pending').addClass('d-none');
        },
        error: function(xhr) {
          if (xhr.status === 409) {
            localStorage.removeItem(`stop_update_${update.id}`);
            $('#mobile-sync-pending').addClass('d-none');
          } else if ([404, 408, 502, 503, 504].includes(xhr.status)) {
            return;
          } else {
            localStorage.removeItem(`stop_update_${update.id}`);
            $('#mobile-sync-failed').removeClass('d-none');
          }
        }
      });
    });
  }

  initServiceWorker();
};

Paloma.controller('Routes', {
  mobile: function() {
    tracking(this.params);
    stops_edit(this.params);
  }
});
