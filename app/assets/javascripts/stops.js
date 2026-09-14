'use strict';

export const stops_edit = function(params) {
  $.find('.no-toggle').forEach(function(button) {
    button.addEventListener('click', function(e) {
      e.stopPropagation();
    });
  })
  $('.radiobtn a, #quick-status').on('click', function() {
    var selected = $(this).data('title');
    changeStatuses($(this), selected);
  });

  $('.custom_field').each(function() {
    var element = $(this).find('input, select, textarea');
    element.on('change', function() {
      var panel = element.closest('.panel');
      submitForm(panel);
    });
  })

  function changeStatuses(element, selected) {
    var panel = $(element).closest('.panel');
    var toggled = $(element).data('toggle');
    var form = panel.find('form');
    // Support both stop forms (stop[status]) and route driver_update forms (route_*_status by id)
    var statusInput = form.find('input[name="stop[status]"]').length
      ? form.find('input[name="stop[status]"]')
      : form.find('#' + toggled);
    if (!statusInput.length) return;

    statusInput.val(selected);
    var updatedAtInput = form.find('input[name="stop[status_updated_at]"]');
    if (updatedAtInput.length) {
      updatedAtInput.val(new Date().toISOString());
    }

    panel.find('.radiobtn a[data-toggle="'+toggled+'"]').not('[data-title="'+selected+'"]').removeClass('active');
    panel.find('.radiobtn a[data-toggle="'+toggled+'"][data-title="'+selected+'"]').addClass('active');

    var label = panel.find('#label-index');
    var labelClasses = label.attr("class") || "";
    var labelMatch = labelClasses.match(/label-[a-z_]*$/);
    if (labelMatch) {
      label.removeClass(labelMatch[0]);
    }
    label.addClass('label-' + selected);

    var heading = panel.find('.panel-heading');
    var headingClasses = heading.attr("class") || "";
    var headingMatch = headingClasses.match(/panel-heading-[a-z_]*$/);
    if (headingMatch) {
      heading.removeClass(headingMatch[0]);
    }
    heading.addClass('panel-heading-' + selected);

    var stopType = panel.data('stop-type');

    // Quick "delivered" shortcut only makes sense for StopVisits
    if (stopType === 'visit' && selected == 'intransit') {
      var next_status = 'delivered';
      panel.find('#quick-status').removeClass('d-none');
      panel.find('#quick-status').data('title', next_status);
      panel.find('#quick-status-text').text(I18n.t("plannings.edit.stop_status.delivered"));
    } else if (stopType === 'store' && selected == 'intransit') {
      var next_status = 'atstore';
      panel.find('#quick-status').removeClass('d-none');
      panel.find('#quick-status').data('title', next_status);
      panel.find('#quick-status-text').text(I18n.t("plannings.edit.stop_store_status.atstore"));
    } else if (stopType === 'store' && selected == 'atstore') {
      var next_status = 'finished';
      panel.find('#quick-status').removeClass('d-none');
      panel.find('#quick-status').data('title', next_status);
      panel.find('#quick-status-text').text(I18n.t("plannings.edit.stop_store_status.finished"));
    } else {
      panel.find('#quick-status').addClass('d-none');
    }
    submitForm(panel);
  }

  function storeStopUpdate(url, formData) {
    const updateData = {
      id: Date.now(),
      url: url,
      formData: formData
    };

    $('#mobile-sync-pending').removeClass('d-none');

    if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({
        type: 'STORE_STOP',
        payload: updateData
      });
    } else {
      localStorage.setItem(`stop_update_${updateData.id}`, JSON.stringify(updateData));
    }
  }

  function submitForm(current_context) {
    const form = current_context.find('form')[0];
    const formData = new FormData(form);
    const url = current_context.find('form').attr('action');

    // Only append stop-specific field for stop forms (not for route driver_update forms)
    if (url.indexOf('/stops/') !== -1) {
      formData.append('stop[status_updated_at]', new Date().toISOString());
    }

    const formObject = {};
    formData.forEach((value, key) => {
      formObject[key] = value;
    });

    if (!navigator.onLine) {
      storeStopUpdate(url, formObject);
      return;
    }

    $.ajax({
      type: 'PATCH',
      url: url,
      data: formData,
      processData: false,
      contentType: false,
      error: () => storeStopUpdate(url, formObject)
    });
  }

  initStopPhotos();
};

var PHOTO_DB = 'planner-mobile-photos';
var PHOTO_STORE = 'pending';

function photoDb() {
  return new Promise(function(resolve, reject) {
    var req = indexedDB.open(PHOTO_DB, 1);
    req.onupgradeneeded = function() {
      if (!req.result.objectStoreNames.contains(PHOTO_STORE)) {
        req.result.createObjectStore(PHOTO_STORE, { keyPath: 'id' });
      }
    };
    req.onsuccess = function() { resolve(req.result); };
    req.onerror = function() { reject(req.error); };
  });
}

export function loadPendingPhotos() {
  return photoDb().then(function(db) {
    return new Promise(function(resolve, reject) {
      var req = db.transaction(PHOTO_STORE, 'readonly').objectStore(PHOTO_STORE).getAll();
      req.onsuccess = function() { resolve(req.result || []); };
      req.onerror = function() { reject(req.error); };
    });
  });
}

export function deletePendingPhoto(id) {
  return photoDb().then(function(db) {
    return new Promise(function(resolve, reject) {
      var tx = db.transaction(PHOTO_STORE, 'readwrite');
      tx.objectStore(PHOTO_STORE).delete(id);
      tx.oncomplete = function() { resolve(); };
      tx.onerror = function() { reject(tx.error); };
    });
  });
}

export function savePendingPhoto(item) {
  return photoDb().then(function(db) {
    return new Promise(function(resolve, reject) {
      var tx = db.transaction(PHOTO_STORE, 'readwrite');
      tx.objectStore(PHOTO_STORE).put(item);
      tx.oncomplete = function() { resolve(); };
      tx.onerror = function() { reject(tx.error); };
    });
  });
}

function findPhotoPanel(url) {
  var found = null;
  $('.stop-photos').each(function() {
    if ($(this).data('url') === url) found = $(this);
  });
  return found;
}

function registerPhotoSync() {
  if ('serviceWorker' in navigator && 'SyncManager' in window) {
    navigator.serviceWorker.ready.then(function(registration) {
      registration.sync.register('sync-photos');
    });
  }
}

function queuePhotoItem(item, panel, files) {
  $('#mobile-sync-pending').removeClass('d-none');
  if (panel && files && files.length) showPendingPhotos(panel, files, item.id);
  savePendingPhoto(item);
  if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
    navigator.serviceWorker.controller.postMessage({ type: 'STORE_PHOTO', payload: item });
    registerPhotoSync();
  }
}

function photoQueueId() {
  return Date.now() + '-' + Math.random().toString(36).slice(2);
}

function queuePhotoUpload(panel, fileList) {
  var files = Array.prototype.slice.call(fileList);
  queuePhotoItem({ id: photoQueueId(), url: panel.data('url'), files: files }, panel, files);
}

function queuePhotoDelete(panel, url) {
  queuePhotoItem({ id: photoQueueId(), url: url, method: 'DELETE', panelUrl: panel.data('url') }, panel, null);
}

function showPendingPhotos(panel, files, pendingId) {
  files.forEach(function(file) {
    var url = URL.createObjectURL(file);
    panel.find('.stop-photos-list').append(
      '<div class="stop-photo stop-photo-pending" data-pending="' + pendingId + '">' +
        '<button type="button" class="stop-photo-open" data-url="' + url + '">' +
          '<img src="' + url + '" alt="">' +
        '</button>' +
      '</div>'
    );
  });
  var count = panel.find('.stop-photo').length;
  panel.find('.stop-photos-badge').text(count);
  panel.find('.stop-photos-accordion').removeClass('d-none');
  panel.find('.stop-photos-panel').removeClass('d-none');
}

export function syncPendingPhotos() {
  var csrf = stopPhotosCsrf();
  return loadPendingPhotos().then(function(items) {
    return Promise.all(items.map(function(item) {
      if (item.method === 'DELETE') {
        return $.ajax({
          type: 'DELETE',
          url: item.url,
          dataType: 'json',
          headers: { 'X-CSRF-Token': csrf, 'X-Requested-With': 'XMLHttpRequest' }
        }).done(function(data) {
          deletePendingPhoto(item.id);
          var panel = findPhotoPanel(item.url.replace(/\/[^/]+$/, ''));
          if (panel) renderStopPhotos(panel, data.photos);
        });
      }
      var formData = new FormData();
      (item.files || []).forEach(function(file) { formData.append('photos[]', file); });
      if (csrf) formData.append('authenticity_token', csrf);
      return $.ajax({
        type: 'POST',
        url: item.url,
        data: formData,
        processData: false,
        contentType: false,
        headers: { 'X-CSRF-Token': csrf }
      }).done(function(data) {
        deletePendingPhoto(item.id);
        var panel = findPhotoPanel(item.url);
        if (panel) renderStopPhotos(panel, data.photos);
      });
    }));
  });
}

export function applyPhotoSync(payload) {
  return deletePendingPhoto(payload.id).then(function() {
    if (payload.photos) {
      var panel = findPhotoPanel(payload.panelUrl || payload.url);
      if (panel) renderStopPhotos(panel, payload.photos);
    }
    return loadPendingPhotos().then(function(items) {
      items.forEach(function(item) {
        if (item.method === 'DELETE' || !item.files) return;
        var p = findPhotoPanel(item.url);
        if (p && !p.find('[data-pending="' + item.id + '"]').length) {
          showPendingPhotos(p, item.files, item.id);
        }
      });
    });
  });
}

function initStopPhotos() {
  // Capture: panel-heading .no-toggle stops bubble before document handlers.
  document.removeEventListener('click', onStopPhotosClick, true);
  document.addEventListener('click', onStopPhotosClick, true);
  bindPhotoModalSwipe();

  $(document).off('change.stopPhotos').on('change.stopPhotos', '.stop-photos-input', function() {
    var input = this;
    if (!input.files.length) return;

    var panel = $(input).closest('.stop-photos');
    var files = Array.prototype.slice.call(input.files);
    var formData = new FormData();
    files.forEach(function(file) { formData.append('photos[]', file); });
    var csrf = stopPhotosCsrf();
    if (csrf) formData.append('authenticity_token', csrf);

    if (!navigator.onLine) {
      queuePhotoUpload(panel, files);
      input.value = '';
      return;
    }

    $.ajax({
      type: 'POST',
      url: panel.data('url'),
      data: formData,
      processData: false,
      contentType: false,
      headers: { 'X-CSRF-Token': csrf }
    }).done(function(data) {
      renderStopPhotos(panel, data.photos);
      input.value = '';
    }).fail(function() {
      queuePhotoUpload(panel, files);
      input.value = '';
    });
  });
}

function onStopPhotosClick(e) {
  var el = e.target;
  if (!el) return;
  if (el.nodeType !== 1) el = el.parentElement;
  if (!el || !el.closest) return;

  var toggle = el.closest('.stop-photos-toggle');
  if (toggle) {
    e.preventDefault();
    e.stopPropagation();
    var panel = toggle.closest('.stop-photos-accordion').querySelector('.stop-photos-panel');
    if (panel) panel.classList.toggle('d-none');
    return;
  }

  var modal = document.getElementById('stop-photo-modal');
  if (modal && !modal.classList.contains('d-none') && modal.contains(el)) {
    e.preventDefault();
    e.stopPropagation();
    if (el.closest('.stop-photo-modal-close')) {
      closeStopPhotoModal();
    } else if (el.closest('.stop-photo-modal-prev')) {
      stepStopPhotoModal(-1);
    } else if (el.closest('.stop-photo-modal-next')) {
      stepStopPhotoModal(1);
    } else if (el.closest('.stop-photo-modal-delete')) {
      var item = photoModalItems[photoModalIndex];
      if (item && item.deleteUrl && photoModalPanel) {
        removeStopPhoto(photoModalPanel, item.deleteUrl);
      }
    } else if (photoModalSwiped) {
      photoModalSwiped = false;
    } else if (!el.closest('.stop-photo-modal-img')) {
      closeStopPhotoModal();
    }
    return;
  }

  var open = el.closest('.stop-photo-open');
  if (open) {
    e.preventDefault();
    e.stopPropagation();
    openStopPhotoModal(open);
    return;
  }

  var remove = el.closest('.stop-photo-remove');
  if (!remove) return;

  e.preventDefault();
  e.stopPropagation();
  removeStopPhoto(remove.closest('.stop-photos'), remove.getAttribute('data-url'));
}

function removeStopPhoto(panelEl, url) {
  var wrap = $(panelEl);
  var csrf = stopPhotosCsrf();

  function goneFromDom() {
    var btn = panelEl.querySelector('.stop-photo-remove[data-url="' + url + '"]');
    if (btn) $(btn.closest('.stop-photo')).remove();
    var count = wrap.find('.stop-photo').length;
    wrap.find('.stop-photos-badge').text(count);
    wrap.find('.stop-photos-accordion').toggleClass('d-none', count === 0);
    syncModalAfterPhotoChange();
  }

  if (!navigator.onLine) {
    queuePhotoDelete(wrap, url);
    goneFromDom();
    return;
  }

  $.ajax({
    type: 'DELETE',
    url: url,
    dataType: 'json',
    headers: { 'X-CSRF-Token': csrf, 'X-Requested-With': 'XMLHttpRequest' }
  }).done(function(data) {
    renderStopPhotos(wrap, data.photos);
    syncModalAfterPhotoChange();
  }).fail(function(xhr) {
    if (xhr.status === 403 && xhr.responseJSON && xhr.responseJSON.photos) {
      renderStopPhotos(wrap, xhr.responseJSON.photos);
      syncModalAfterPhotoChange();
      return;
    }
    queuePhotoDelete(wrap, url);
    goneFromDom();
  });
}

function stopPhotosCsrf() {
  var meta = document.querySelector('meta[name="csrf-token"]');
  return meta ? meta.content : '';
}

var photoModalItems = [];
var photoModalIndex = 0;
var photoModalPanel = null;
var photoModalTouchStartX = null;
var photoModalSwiped = false;

function photoItemsFromOpen(openBtn) {
  var list = openBtn.closest('.stop-photos-list');
  if (!list) return [{ url: openBtn.getAttribute('data-url'), deleteUrl: null }];
  return Array.prototype.map.call(list.querySelectorAll('.stop-photo'), function(el) {
    var open = el.querySelector('.stop-photo-open');
    var remove = el.querySelector('.stop-photo-remove');
    return {
      url: open ? open.getAttribute('data-url') : null,
      deleteUrl: remove ? remove.getAttribute('data-url') : null
    };
  }).filter(function(item) { return item.url; });
}

function updateStopPhotoModalChrome() {
  var modal = document.getElementById('stop-photo-modal');
  if (!modal) return;
  var hideNav = photoModalItems.length < 2;
  modal.querySelectorAll('.stop-photo-modal-nav').forEach(function(btn) {
    btn.classList.toggle('d-none', hideNav);
  });
  var del = modal.querySelector('.stop-photo-modal-delete');
  if (!del) return;
  var item = photoModalItems[photoModalIndex];
  del.classList.toggle('d-none', !(item && item.deleteUrl));
}

function showStopPhotoAt(index) {
  var modal = document.getElementById('stop-photo-modal');
  if (!modal || !photoModalItems.length) return;
  photoModalIndex = (index + photoModalItems.length) % photoModalItems.length;
  var img = modal.querySelector('.stop-photo-modal-img');
  if (img) img.src = photoModalItems[photoModalIndex].url;
  updateStopPhotoModalChrome();
}

function stepStopPhotoModal(delta) {
  if (photoModalItems.length < 2) return;
  showStopPhotoAt(photoModalIndex + delta);
}

function openStopPhotoModal(openBtn) {
  var modal = document.getElementById('stop-photo-modal');
  var url = openBtn && openBtn.getAttribute('data-url');
  if (!modal || !url) return;
  photoModalPanel = openBtn.closest('.stop-photos');
  photoModalItems = photoItemsFromOpen(openBtn);
  var index = -1;
  for (var i = 0; i < photoModalItems.length; i++) {
    if (photoModalItems[i].url === url) { index = i; break; }
  }
  modal.classList.remove('d-none');
  showStopPhotoAt(index < 0 ? 0 : index);
}

function closeStopPhotoModal() {
  var modal = document.getElementById('stop-photo-modal');
  if (!modal) return;
  modal.classList.add('d-none');
  photoModalItems = [];
  photoModalIndex = 0;
  photoModalPanel = null;
  var img = modal.querySelector('.stop-photo-modal-img');
  if (img) img.removeAttribute('src');
}

function syncModalAfterPhotoChange() {
  var modal = document.getElementById('stop-photo-modal');
  if (!modal || modal.classList.contains('d-none') || !photoModalPanel) return;
  var current = photoModalItems[photoModalIndex];
  var currentUrl = current && current.url;
  var open = photoModalPanel.querySelector('.stop-photo-open');
  if (!open) {
    closeStopPhotoModal();
    return;
  }
  photoModalItems = photoItemsFromOpen(open);
  var idx = -1;
  for (var i = 0; i < photoModalItems.length; i++) {
    if (photoModalItems[i].url === currentUrl) { idx = i; break; }
  }
  if (idx < 0) idx = Math.min(photoModalIndex, photoModalItems.length - 1);
  showStopPhotoAt(idx);
}

function onPhotoModalTouchStart(e) {
  photoModalTouchStartX = e.changedTouches[0].clientX;
  photoModalSwiped = false;
}

function onPhotoModalTouchEnd(e) {
  if (photoModalTouchStartX == null) return;
  var dx = e.changedTouches[0].clientX - photoModalTouchStartX;
  photoModalTouchStartX = null;
  if (Math.abs(dx) < 40) return;
  photoModalSwiped = true;
  stepStopPhotoModal(dx < 0 ? 1 : -1);
}

function bindPhotoModalSwipe() {
  var modal = document.getElementById('stop-photo-modal');
  if (!modal || modal.dataset.swipeBound) return;
  modal.dataset.swipeBound = '1';
  modal.addEventListener('touchstart', onPhotoModalTouchStart, { passive: true });
  modal.addEventListener('touchend', onPhotoModalTouchEnd, { passive: true });
}

export function renderStopPhotos(panel, photos) {
  var list = panel.find('.stop-photos-list');
  var baseUrl = panel.data('url');
  photos = photos || [];
  list.empty();
  photos.forEach(function(photo) {
    var remove = photo.deletable === false ? '' :
      '<button type="button" class="stop-photo-remove btn btn-xs btn-default" data-url="' + baseUrl + '/' + photo.id + '">' +
        '<i class="fa fa-trash"></i>' +
      '</button>';
    list.append(
      '<div class="stop-photo">' +
        remove +
        '<button type="button" class="stop-photo-open" data-url="' + photo.url + '">' +
          '<img src="' + photo.url + '" alt="">' +
        '</button>' +
      '</div>'
    );
  });
  panel.find('.stop-photos-badge').text(photos.length);
  panel.find('.stop-photos-accordion').toggleClass('d-none', photos.length === 0);
  panel.find('.stop-photos-panel').removeClass('d-none');
}
