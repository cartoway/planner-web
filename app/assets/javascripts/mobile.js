'use strict';

import { beforeSendWaiting, completeWaiting, ajaxError } from '../../assets/javascripts/ajax';
import { stops_edit } from '../../assets/javascripts/stops';

const tracking = function(params) {
  let positionInterval = null;
  let messageListener;

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
        startInterval();
      }
    };

    navigator.serviceWorker.addEventListener('message', messageListener);

    const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
    navigator.serviceWorker.register('/service-worker.js', {
      scope: '/'
    })
    .then(registration => {
      if (registration.active) {
        registration.active.postMessage({
          type: 'SET_CSRF_TOKEN',
          token: token
        });
      }

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
        beforeSend: function() {
          beforeSendWaiting();
        },
        complete: function() {
          completeWaiting();
        }
      });
    } else {
      stopInterval();
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
        if (hasPendingData('position_')) {
          navigator.serviceWorker.ready
            .then(registration => {
              return registration.sync.register('sync-positions');
            })
        }
        if (hasPendingData('stop_update_')) {
          navigator.serviceWorker.ready
            .then(registration => {
              return registration.sync.register('sync-stops');
            })
        }
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

  function registerServiceWorker() {
    if (!('serviceWorker' in navigator)) {
      return;
    }

    if (!navigator.serviceWorker) {
      return;
    }

    navigator.serviceWorker.register('/service-worker.js', {
      scope: '/'
    })
  }

  if (window.isSecureContext && 'serviceWorker' in navigator && 'SyncManager' in window) {
    registerServiceWorker();
  }

  getPosition();

  initTracking();

  window.addEventListener('online', () => {
    checkPendingData();
  });

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
