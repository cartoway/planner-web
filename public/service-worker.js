const positionsSync = {
  sync: () => syncPositions(),
  getStored: () => getStoredPositions(),
  remove: (id) => removeStoredPosition(id)
};

const stopsSync = {
  sync: () => syncStops(),
  getStored: () => getStoredStopUpdates(),
  remove: (id) => removeStoredStopUpdate(id)
};

self.addEventListener('sync', event => {
  switch(event.tag) {
    case 'sync-positions':
      event.waitUntil(positionsSync.sync());
      break;
    case 'sync-stops':
      event.waitUntil(stopsSync.sync());
      break;
  }
});

self.addEventListener('online', () => {
  syncPendingData();
});

const pendingRequests = {
  positions: new Set(),
  stops: new Set()
};

let csrfToken;

self.addEventListener('message', event => {
  switch(event.data.type) {
    case 'STORE_POSITION':
      pendingRequests.positions.add(event.data.payload);
      break;
    case 'STORE_STOP':
      pendingRequests.stops.add(event.data.payload);
      break;
    case 'SET_CSRF_TOKEN':
      csrfToken = event.data.token;
      break;
  }
});

function syncPendingData() {
  return Promise.all([
    syncPositions(),
    syncStops()
  ]);
}

function notifyClients(type, data) {
  self.clients.matchAll().then(clients => {
    clients.forEach(client => {
      client.postMessage({ type, data });
    });
  });
}

self.addEventListener('install', event => {
  event.waitUntil(
    Promise.all([
      self.skipWaiting()
    ])
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    Promise.all([
      self.clients.claim()
    ])
  );
});

function syncPositions() {
  if (!csrfToken) {
    return Promise.reject(new Error('No CSRF token available'));
  }

  return Promise.all(Array.from(pendingRequests.positions).map(position => {
    return fetch(`/routes/${position.routeId}/update_position`, {
      method: 'PATCH',
      body: JSON.stringify(position.coords),
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(() => {
      pendingRequests.positions.delete(position);
      notifyClients('POSITION_SYNCED', position);
    });
  }));
}

function syncStops() {
  if (!csrfToken) {
    Array.from(pendingRequests.stops).forEach(stop => {
      localStorage.setItem(`stop_update_${stop.id}`, JSON.stringify(stop));
      pendingRequests.stops.delete(stop);
    });
    return Promise.reject(new Error('No CSRF token available'));
  }

  return Promise.all(Array.from(pendingRequests.stops).map(stop => {
    const formData = new FormData();
    Object.keys(stop.formData).forEach(key => {
      formData.append(key, stop.formData[key]);
    });
    formData.append('authenticity_token', csrfToken);
    formData.append('_method', 'PATCH');

    return fetch(stop.url, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-CSRF-Token': csrfToken,
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(() => {
      pendingRequests.stops.delete(stop);
      notifyClients('STOP_SYNCED', stop);
    })
    .catch(error => {
      notifyClients('SYNC_ERROR', {
        type: 'stop',
        url: stop.url,
        error: error.message
      });
      throw error;
    });
  }));
}
