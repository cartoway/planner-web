self.addEventListener('sync', event => {
  if (!csrfToken) {
    event.waitUntil(
      new Promise((resolve) => {
        let attempts = 0;
        const checkToken = setInterval(() => {
          attempts++;
          if (csrfToken) {
            clearInterval(checkToken);
            switch(event.tag) {
              case 'sync-positions':
                resolve(syncPositions());
                break;
              case 'sync-stops':
                resolve(syncStops());
                break;
            }
          } else if (attempts >= 5) {
            clearInterval(checkToken);
            if (event.tag === 'sync-positions') {
              notifyClients('STORE_POSITIONS', Array.from(pendingRequests.positions));
            } else {
              notifyClients('STORE_STOPS', Array.from(pendingRequests.stops));
            }
            resolve();
          }
        }, 1000);
      })
    );
    return;
  }

  switch(event.tag) {
    case 'sync-positions':
      event.waitUntil(syncPositions());
      break;
    case 'sync-stops':
      event.waitUntil(syncStops());
      break;
  }
});

const pendingRequests = {
  positions: new Set(),
  stops: new Set()
};

let csrfToken;

function getAllPendingData() {
  return new Promise((resolve) => {
    self.clients.matchAll().then(clients => {
      if (!clients.length) {
        resolve({ positions: [], stops: [] });
        return;
      }

      const activeClient = clients[0];

      let messageHandler = function(event) {
        if (event.data.type === 'PENDING_DATA') {
          self.removeEventListener('message', messageHandler);
          event.data.data.positions.forEach(position => {
            pendingRequests.positions.add(position);
          });
          event.data.data.stops.forEach(stop => {
            pendingRequests.stops.add(stop);
          });
          resolve(event.data.data);
        }
      };

      self.addEventListener('message', messageHandler);
      activeClient.postMessage({ type: 'GET_PENDING_DATA' });

      setTimeout(() => {
        self.removeEventListener('message', messageHandler);
        resolve({ positions: [], stops: [] });
      }, 3000);
    });
  });
}

function checkAndSync() {
  if (navigator.onLine) {
    setTimeout(() => {
      if (!csrfToken) {
        return;
      }
      syncPendingData();
    }, 1000);
  }
}

self.addEventListener('online', checkAndSync);
setInterval(checkAndSync, 10000);

self.addEventListener('message', event => {
  switch(event.data.type) {
    case 'SKIP_WAITING':
      self.skipWaiting();
      break;
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
      self.skipWaiting(),
      getAllPendingData()
    ])
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    Promise.all([
      self.clients.claim(),
      getAllPendingData()
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
    .then(response => {
      if (response.ok) {
        pendingRequests.positions.delete(position);
        notifyClients('POSITION_SYNCED', position);
      }
    })
    .catch(error => {
      notifyClients('SYNC_ERROR', {
        type: 'position',
        error: error.message
      });
      throw error;
    });
  }));
}

function syncStops() {
  if (!csrfToken) {
    notifyClients('STORE_STOPS', Array.from(pendingRequests.stops));
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
    .then(response => {
      if (response.ok) {
        pendingRequests.stops.delete(stop);
        notifyClients('STOP_SYNCED', stop);
      }
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
