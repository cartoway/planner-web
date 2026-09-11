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
              case 'sync-routes':
                resolve(syncRoutes());
                break;
              case 'sync-photos':
                resolve(syncPhotos());
                break;
            }
          } else if (attempts >= 5) {
            clearInterval(checkToken);
            switch (event.tag) {
              case 'sync-positions':
                notifyClients('STORE_POSITIONS', Array.from(pendingRequests.positions));
                break;
              case 'sync-stops':
                notifyClients('STORE_STOPS', Array.from(pendingRequests.stops));
                break;
              case 'sync-routes':
                notifyClients('STORE_ROUTES', Array.from(pendingRequests.routes));
                break;
              case 'sync-photos':
                notifyClients('STORE_PHOTOS', Array.from(pendingRequests.photos));
                break;
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
    case 'sync-routes':
      event.waitUntil(syncRoutes());
      break;
    case 'sync-photos':
      event.waitUntil(syncPhotos());
      break;
  }
});

const pendingRequests = {
  positions: new Set(),
  stops: new Set(),
  routes: new Set(),
  photos: new Set()
};

function addPendingPhoto(item) {
  Array.from(pendingRequests.photos).forEach(function(existing) {
    if (existing.id === item.id) pendingRequests.photos.delete(existing);
  });
  pendingRequests.photos.add(item);
}

let csrfToken;

function getAllPendingData() {
  return new Promise((resolve) => {
    self.clients.matchAll().then(clients => {
      if (!clients.length) {
        resolve({ positions: [], stops: [], routes: [], photos: [] });
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
          if (event.data.data.routes) {
            event.data.data.routes.forEach(routeUpdate => {
              pendingRequests.routes.add(routeUpdate);
            });
          }
          if (event.data.data.photos) {
            event.data.data.photos.forEach(photo => addPendingPhoto(photo));
          }
          resolve(event.data.data);
        }
      };

      self.addEventListener('message', messageHandler);
      activeClient.postMessage({ type: 'GET_PENDING_DATA' });

      setTimeout(() => {
        self.removeEventListener('message', messageHandler);
        resolve({ positions: [], stops: [], photos: [] });
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
    case 'STORE_ROUTE':
      pendingRequests.routes.add(event.data.payload);
      break;
    case 'STORE_PHOTO':
      addPendingPhoto(event.data.payload);
      break;
    case 'SET_CSRF_TOKEN':
      csrfToken = event.data.token;
      break;
  }
});

function syncPendingData() {
  return Promise.all([
    syncPositions(),
    syncStops(),
    syncRoutes(),
    syncPhotos()
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

// Generic helper to sync collections sent as FormData (stops, routes)
function syncFormDataCollection(options) {
  const { collectionKey, successEvent, storeEvent, syncErrorType } = options;

  if (!csrfToken) {
    // No CSRF token available, keep items and ask client to persist them
    notifyClients(storeEvent, Array.from(pendingRequests[collectionKey]));
    return Promise.reject(new Error('No CSRF token available'));
  }

  return Promise.all(Array.from(pendingRequests[collectionKey]).map(item => {
    // Handle retry-after logic for transient errors (e.g. deadlocks)
    if (item.retryAfter && item.retryAfter > Date.now()) {
      pendingRequests[collectionKey].delete(item);
      notifyClients(storeEvent, Array.from([item]));
      return Promise.resolve();
    }

    const formData = new FormData();
    Object.keys(item.formData).forEach(key => {
      formData.append(key, item.formData[key]);
    });
    // Ensure authenticity token is present
    if (!formData.has('authenticity_token')) {
      formData.append('authenticity_token', csrfToken);
    }
    formData.append('_method', 'PATCH');

    const jsonUrl = item.url + (item.url.includes('?') ? '&' : '?') + 'format=json';

    return fetch(jsonUrl, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-CSRF-Token': csrfToken,
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => {
      pendingRequests[collectionKey].delete(item);
      if (response.ok) {
        notifyClients(successEvent, item);
        return;
      }

      return response.json().then(data => {
        const errorType = (data && data.type) || '';

        switch (response.status) {
          case 404:
          case 408:
          case 502:
          case 503:
          case 504:
            notifyClients(storeEvent, Array.from([item]));
            break;
          case 409:
            break;
          case 422:
            if (errorType.includes('deadlock')) {
              item.retryAfter = Date.now() + 500;
              notifyClients(storeEvent, Array.from([item]));
            }
            break;
          default:
            throw new Error(`Failed to sync ${syncErrorType}: ${response.status}`);
        }
      });
    })
    .catch(error => {
      notifyClients('SYNC_ERROR', {
        type: syncErrorType,
        url: item.url,
        error: error.message
      });
    });
  }));
}

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
            case 409:
              break;
            case 422:
              if (errorType.includes('deadlock')) {
                position.retryAfter = Date.now() + 500;
                notifyClients('STORE_POSITIONS', Array.from([{
                  position
                }]));
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
  return syncFormDataCollection({
    collectionKey: 'stops',
    successEvent: 'STOP_SYNCED',
    storeEvent: 'STORE_STOPS',
    syncErrorType: 'stop'
  });
}

function syncRoutes() {
  return syncFormDataCollection({
    collectionKey: 'routes',
    successEvent: 'ROUTE_SYNCED',
    storeEvent: 'STORE_ROUTES',
    syncErrorType: 'route'
  });
}

function syncPhotos() {
  if (!csrfToken) {
    notifyClients('STORE_PHOTOS', Array.from(pendingRequests.photos));
    return Promise.reject(new Error('No CSRF token available'));
  }

  return Promise.all(Array.from(pendingRequests.photos).map(item => {
    if (item.retryAfter && item.retryAfter > Date.now()) {
      pendingRequests.photos.delete(item);
      notifyClients('STORE_PHOTOS', Array.from([item]));
      return Promise.resolve();
    }

    const headers = {
      'X-CSRF-Token': csrfToken,
      'X-Requested-With': 'XMLHttpRequest'
    };
    let request;
    if (item.method === 'DELETE') {
      request = fetch(item.url, { method: 'DELETE', headers: headers });
    } else {
      const formData = new FormData();
      (item.files || []).forEach(file => formData.append('photos[]', file));
      formData.append('authenticity_token', csrfToken);
      request = fetch(item.url, { method: 'POST', body: formData, headers: headers });
    }

    return request
      .then(response => {
        pendingRequests.photos.delete(item);
        if (response.ok) {
          return response.json().then(data => {
            notifyClients('PHOTO_SYNCED', {
              id: item.id,
              url: item.url,
              panelUrl: item.panelUrl || item.url,
              photos: data.photos
            });
          });
        }
        if (item.method === 'DELETE' && response.status === 404) {
          notifyClients('PHOTO_SYNCED', {
            id: item.id,
            url: item.url,
            panelUrl: item.panelUrl || item.url
          });
          return;
        }

        return response.json().then(data => {
          const errorType = (data && data.type) || '';
          switch (response.status) {
            case 404:
            case 408:
            case 502:
            case 503:
            case 504:
              notifyClients('STORE_PHOTOS', Array.from([item]));
              break;
            case 409:
              break;
            case 403:
              notifyClients('PHOTO_SYNCED', {
                id: item.id,
                url: item.url,
                panelUrl: item.panelUrl || item.url,
                photos: data.photos
              });
              break;
            case 422:
              if (errorType.includes('deadlock')) {
                item.retryAfter = Date.now() + 500;
                notifyClients('STORE_PHOTOS', Array.from([item]));
              }
              break;
            default:
              throw new Error('Failed to sync photo: ' + response.status);
          }
        });
      })
      .catch(error => {
        notifyClients('SYNC_ERROR', {
          type: 'photo',
          url: item.url,
          error: error.message
        });
        notifyClients('STORE_PHOTOS', Array.from([item]));
      });
  }));
}
