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
      getAllPendingData().then(() => {
        syncPendingData();
      });
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
    if (position.retryAfter && position.retryAfter > Date.now()) {
      pendingRequests.positions.delete(position);
      notifyClients('STORE_POSITIONS', Array.from([position]));
      return Promise.resolve();
    }

    return fetch(`/routes/${position.routeId}/update_position.json`, {
      method: 'PATCH',
      body: JSON.stringify(position.coords),
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => {
      pendingRequests.positions.delete(position);
      if (response.ok) {
        notifyClients('POSITION_SYNCED', position);
      } else {
        return response.json().then(data => {
          const errorType = data.type;

          switch(response.status) {
            case 404:
            case 408:
            case 502:
            case 503:
            case 504:
              notifyClients('STORE_POSITIONS', Array.from([position]));
              break;
            case 422:
              if (errorType.includes('deadlock')) {
                position.retryAfter = Date.now() + 500;
                notifyClients('STORE_POSITIONS', Array.from([{
                  position
                }]));
                throw new Error('retry_later');
              }
            default:
              throw new Error(`Failed to sync position: ${response.status}`);
          }
        });
      }
    })
    .catch(error => {
      notifyClients('SYNC_ERROR', {
        type: 'position',
        error: error.message
      });
    });
  }));
}

function syncStops() {
  if (syncInProgress) {
    return Promise.resolve();
  }

  if (!csrfToken) {
    notifyClients('STORE_STOPS', Array.from(pendingRequests.stops));
    return Promise.reject(new Error('No CSRF token available'));
  }

  return Promise.all(Array.from(pendingRequests.stops).map(stop => {
    if (stop.retryAfter && stop.retryAfter > Date.now()) {
      pendingRequests.stops.delete(stop);
      notifyClients('STORE_STOPS', Array.from([stop]));
      return Promise.resolve();
    }

    const formData = new FormData();
    Object.keys(stop.formData).forEach(key => {
      formData.append(key, stop.formData[key]);
    });
    formData.append('authenticity_token', csrfToken);
    formData.append('_method', 'PATCH');

    const jsonUrl = stop.url + (stop.url.includes('?') ? '&' : '?') + 'format=json';

    return fetch(jsonUrl, {
      method: 'PATCH',
      body: formData,
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => {
      pendingRequests.stops.delete(stop);
      if (response.ok) {
        notifyClients('STOP_SYNCED', stop);
      } else {
        return response.json().then(data => {
          const errorType = data.type;

          switch(response.status) {
            case 404:
            case 408:
            case 502:
            case 503:
            case 504:
              notifyClients('STORE_STOPS', Array.from([stop]));
              break;
            case 422:
              if (errorType.includes('deadlock')) {
                stop.retryAfter = Date.now() + 500;
                notifyClients('STORE_STOPS', Array.from([{
                  stop
                }]));
                throw new Error('retry_later');
              }
            default:
              throw new Error(`Failed to sync stop: ${response.status}`);
          }
        });
      }
    })
    .catch(error => {
      notifyClients('SYNC_ERROR', {
        type: 'stop',
        url: stop.url,
        error: error.message
      });
    });
  }));
}
