'use strict';

export const stops_edit = function(params) {
  var CONFIRM_ARMED = 'confirm-click-armed';
  var CONFIRM_PENDING = 'confirm-click-pending';
  var CONFIRM_ARMED_BTN = 'btn-warning';
  var CONFIRM_BASE_BTN = 'btn-default';
  var CONFIRM_DELAY = 200;
  var CONFIRM_DISARM_AFTER = 4000;

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

  function clearConfirmTimers(btn) {
    window.clearTimeout(btn._confirmReadyTimeout);
    window.clearTimeout(btn._disarmTimeout);
    btn._confirmReadyTimeout = null;
    btn._disarmTimeout = null;
  }

  function statusResetFace(btn) {
    return btn.querySelector('.stop-status-reset-face') || btn;
  }

  function disarmStatusReset(btn) {
    if (!btn || !btn.classList.contains(CONFIRM_ARMED)) return;
    clearConfirmTimers(btn);
    var face = statusResetFace(btn);
    btn.classList.remove(CONFIRM_ARMED, CONFIRM_PENDING);
    face.classList.remove(CONFIRM_ARMED_BTN);
    face.classList.add(CONFIRM_BASE_BTN);
    face.style.opacity = '';
    if (btn._originalHtml != null) btn.innerHTML = btn._originalHtml;
    btn.title = btn._originalTitle || '';
    btn._armedAt = null;
  }

  function disarmAllStatusResets(except) {
    document.querySelectorAll('.stop-status-reset.' + CONFIRM_ARMED).forEach(function(btn) {
      if (btn !== except) disarmStatusReset(btn);
    });
  }

  function armStatusReset(btn) {
    btn._originalHtml = btn.innerHTML;
    btn._originalTitle = btn.title || '';
    var face = statusResetFace(btn);
    btn.classList.add(CONFIRM_ARMED, CONFIRM_PENDING);
    face.classList.add(CONFIRM_ARMED_BTN);
    face.classList.remove(CONFIRM_BASE_BTN);
    face.style.opacity = '0.55';
    btn.title = btn.getAttribute('data-wait-message') || '';
    btn._armedAt = Date.now();

    btn._confirmReadyTimeout = window.setTimeout(function() {
      btn.classList.remove(CONFIRM_PENDING);
      face.style.opacity = '';
      var readyHtml = btn.getAttribute('data-ready-html');
      if (readyHtml) face.innerHTML = readyHtml;
      btn.title = btn.getAttribute('data-confirm-message') || '';
    }, CONFIRM_DELAY);

    btn._disarmTimeout = window.setTimeout(function() {
      disarmStatusReset(btn);
    }, CONFIRM_DISARM_AFTER);
  }

  $('.stop-status-reset').on('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    var btn = this;
    if (!btn.classList.contains(CONFIRM_ARMED)) {
      disarmAllStatusResets(btn);
      armStatusReset(btn);
      return;
    }
    if (btn.classList.contains(CONFIRM_PENDING) || Date.now() - (btn._armedAt || 0) < CONFIRM_DELAY) {
      return;
    }
    disarmStatusReset(btn);
    changeStatuses($(btn), '');
  });

  $(document).on('click.statusResetDisarm', function(e) {
    if (!e.target.closest('.stop-status-reset.' + CONFIRM_ARMED)) {
      disarmAllStatusResets();
    }
  });

  // iOS: try BeNav deep link, fall back to Apple Maps (href) if the page stays visible
  var NAV_FALLBACK_MS = 1200;
  $('.mobile-nav-link').on('click', function(e) {
    var primary = this.getAttribute('data-nav-primary');
    if (!primary) return;

    e.preventDefault();
    e.stopPropagation();

    var fallback = this.getAttribute('href');
    var startedAt = Date.now();
    var fallbackTimer = window.setTimeout(function() {
      if (!document.hidden && Date.now() - startedAt < NAV_FALLBACK_MS + 500) {
        window.location.href = fallback;
      }
    }, NAV_FALLBACK_MS);

    var onVisibility = function() {
      if (document.hidden) {
        window.clearTimeout(fallbackTimer);
        document.removeEventListener('visibilitychange', onVisibility);
      }
    };
    document.addEventListener('visibilitychange', onVisibility);
    window.location.href = primary;
  });

  function changeStatuses(element, selected) {
    var panel = $(element).closest('.panel');
    var toggled = $(element).data('toggle') || 'active_status';
    var form = panel.find('form');
    // Support both stop forms (stop[status]) and route driver_update forms (route_*_status by id)
    var statusInput = form.find('input[name="stop[status]"]').length
      ? form.find('input[name="stop[status]"]')
      : form.find('#' + toggled);
    if (!statusInput.length) return;

    // Empty title = reset to default (nil) status; nilify_blanks on Stop clears ""
    selected = selected || '';
    statusInput.val(selected);
    var updatedAtInput = form.find('input[name="stop[status_updated_at]"]');
    if (updatedAtInput.length) {
      updatedAtInput.val(new Date().toISOString());
    }

    panel.find('.radiobtn a[data-toggle="'+toggled+'"]').removeClass('active');
    if (selected) {
      panel.find('.radiobtn a[data-toggle="'+toggled+'"][data-title="'+selected+'"]').addClass('active');
    }

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

    panel.find('.stop-status-reset').toggleClass('d-none', !selected);

    var stopType = panel.data('stop-type');

    // Quick next-status shortcut after reset / status change
    if (!selected) {
      var nextAfterReset = element.data('next-status') || 'intransit';
      var statusI18nPrefix = stopType === 'visit'
        ? 'plannings.edit.stop_status.'
        : 'plannings.edit.stop_store_status.';
      panel.find('#quick-status').removeClass('d-none');
      panel.find('#quick-status').data('title', nextAfterReset);
      panel.find('#quick-status-text').text(I18n.t(statusI18nPrefix + nextAfterReset));
    } else if (stopType === 'visit' && selected == 'intransit') {
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
  initStopSignature();
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
  var list = documentsRoot(panel).find('.stop-documents-list');
  files.forEach(function(file) {
    var url = URL.createObjectURL(file);
    list.append(
      '<div class="stop-photo stop-photo-pending" data-pending="' + pendingId + '">' +
        '<button type="button" class="stop-photo-open" data-url="' + url + '">' +
          '<img src="' + url + '" alt="">' +
        '</button>' +
      '</div>'
    );
  });
  updateDocumentsBadge(documentsRoot(panel));
}

function documentsRoot(el) {
  return $(el).closest('.stop-documents');
}

function updateDocumentsBadge(root) {
  if (!root || !root.length) return;
  var count = root.find('.stop-documents-list .stop-photo').length;
  root.find('.stop-documents-badge').text(count);
  root.find('.stop-documents-accordion').toggleClass('d-none', count === 0);
  root.find('.stop-documents-panel').removeClass('d-none');
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
        }).then(function(data) {
          return deletePendingPhoto(item.id).then(function() {
            var panel = findPhotoPanel(item.panelUrl || item.url.replace(/\/[^/]+$/, ''));
            if (panel && data && data.photos) renderStopPhotos(panel, data.photos);
          });
        }, function(xhr) {
          // Already deleted on server (e.g. first DELETE succeeded but response was lost)
          if (xhr && xhr.status === 404) {
            return deletePendingPhoto(item.id);
          }
          // Keep pending for retriable / unknown errors; swallow rejection to avoid loop noise
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
      }).then(function(data) {
        return deletePendingPhoto(item.id).then(function() {
          var panel = findPhotoPanel(item.url);
          if (panel) renderStopPhotos(panel, data.photos);
        });
      }, function() {
        // Keep pending for retry
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

  var toggle = el.closest('.stop-documents-toggle');
  if (toggle) {
    e.preventDefault();
    e.stopPropagation();
    var panel = toggle.closest('.stop-documents-accordion').querySelector('.stop-documents-panel');
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
  var docs = remove.closest('.stop-documents');
  var photosPanel = docs ? docs.querySelector('.stop-photos') : remove.closest('.stop-photos');
  removeStopPhoto(photosPanel, remove.getAttribute('data-url'));
}

function removeStopPhoto(panelEl, url) {
  var wrap = $(panelEl);
  var csrf = stopPhotosCsrf();

  function goneFromDom() {
    var btn = panelEl.querySelector('.stop-photo-remove[data-url="' + url + '"]');
    if (btn) $(btn.closest('.stop-photo')).remove();
    updateDocumentsBadge(documentsRoot(wrap));
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
    // Photo already gone (previous DELETE succeeded without a response reaching us)
    if (xhr.status === 404) {
      goneFromDom();
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
  var list = openBtn.closest('.stop-documents-list');
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
  photoModalPanel = openBtn.closest('.stop-documents')
    ? openBtn.closest('.stop-documents').querySelector('.stop-photos')
    : openBtn.closest('.stop-photos');
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
  var root = documentsRoot(panel);
  var list = root.find('.stop-documents-list');
  var baseUrl = panel.data('url');
  photos = photos || [];
  list.find('.stop-photo').not('.stop-signature-doc').remove();
  photos.forEach(function(photo) {
    var remove = photo.deletable === false ? '' :
      '<button type="button" class="stop-photo-remove btn btn-xs btn-default" data-url="' + baseUrl + '/' + photo.id + '">' +
        '<i class="fa fa-trash"></i>' +
      '</button>';
    var html =
      '<div class="stop-photo">' +
        remove +
        '<button type="button" class="stop-photo-open" data-url="' + photo.url + '">' +
          '<img src="' + photo.url + '" alt="">' +
        '</button>' +
      '</div>';
    var signatureDoc = list.find('.stop-signature-doc');
    if (signatureDoc.length) signatureDoc.before(html);
    else list.append(html);
  });
  updateDocumentsBadge(root);
}

function renderStopSignature(wrap, signature) {
  var root = documentsRoot(wrap);
  var list = root.find('.stop-documents-list');
  list.find('.stop-signature-doc').remove();
  if (signature) {
    list.append(
      '<div class="stop-photo stop-signature-doc">' +
        '<button type="button" class="stop-photo-open" data-url="' + signature.url + '">' +
          '<img src="' + signature.url + '" alt="">' +
        '</button>' +
      '</div>'
    );
  }
  updateDocumentsBadge(root);
}

function initStopSignature() {
  var signaturePanel = null;

  $(document).off('click.stopSignatureOpen').on('click.stopSignatureOpen', '.stop-signature-open', function(e) {
    e.preventDefault();
    e.stopPropagation();
    signaturePanel = $(this).closest('.stop-signature');
    openStopSignatureModal();
  });

  $(document).off('click.stopSignatureClose').on('click.stopSignatureClose', '.stop-signature-modal-close', function(e) {
    e.preventDefault();
    e.stopPropagation();
    closeStopSignatureModal();
  });

  $(document).off('click.stopSignatureClear').on('click.stopSignatureClear', '.stop-signature-clear', function(e) {
    e.preventDefault();
    e.stopPropagation();
    clearSignatureCanvas(document.querySelector('#stop-signature-modal .stop-signature-canvas'));
  });

  $(document).off('click.stopSignatureSave').on('click.stopSignatureSave', '.stop-signature-save', function(e) {
    e.preventDefault();
    e.stopPropagation();
    var canvas = document.querySelector('#stop-signature-modal .stop-signature-canvas');
    if (!canvas || !canvas.dataset.dirty || !signaturePanel) return;

    canvas.toBlob(function(blob) {
      if (!blob) return;
      var formData = new FormData();
      formData.append('signature', blob, 'signature.png');
      var csrf = stopPhotosCsrf();
      if (csrf) formData.append('authenticity_token', csrf);

      $.ajax({
        type: 'POST',
        url: signaturePanel.data('url'),
        data: formData,
        processData: false,
        contentType: false,
        headers: { 'X-CSRF-Token': csrf }
      }).done(function(data) {
        renderStopSignature(signaturePanel, data.signature);
        closeStopSignatureModal();
      });
    }, 'image/png');
  });

}
function openStopSignatureModal() {
  var modal = document.getElementById('stop-signature-modal');
  if (!modal) return;
  var canvas = modal.querySelector('.stop-signature-canvas');
  modal.classList.remove('d-none');
  document.body.style.overflow = 'hidden';
  resizeSignatureCanvas(canvas);
  setupSignatureCanvas(canvas);
  clearSignatureCanvas(canvas);
}

function closeStopSignatureModal() {
  var modal = document.getElementById('stop-signature-modal');
  if (!modal) return;
  modal.classList.add('d-none');
  document.body.style.overflow = '';
  clearSignatureCanvas(modal.querySelector('.stop-signature-canvas'));
}

function resizeSignatureCanvas(canvas) {
  if (!canvas) return;
  var pad = canvas.parentElement;
  if (!pad) return;
  var width = Math.max(pad.clientWidth, 1);
  var height = Math.max(pad.clientHeight, 1);
  canvas.width = width * 2;
  canvas.height = height * 2;
}

function setupSignatureCanvas(canvas) {
  if (!canvas || canvas.dataset.bound) return;
  canvas.dataset.bound = '1';
  var ctx = canvas.getContext('2d');
  var drawing = false;

  function pos(e) {
    var rect = canvas.getBoundingClientRect();
    var src = e.touches && e.touches[0] ? e.touches[0] : e;
    return {
      x: (src.clientX - rect.left) * (canvas.width / rect.width),
      y: (src.clientY - rect.top) * (canvas.height / rect.height)
    };
  }

  function start(e) {
    e.preventDefault();
    drawing = true;
    var p = pos(e);
    ctx.beginPath();
    ctx.moveTo(p.x, p.y);
  }

  function move(e) {
    if (!drawing) return;
    e.preventDefault();
    var p = pos(e);
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.strokeStyle = '#111';
    ctx.lineTo(p.x, p.y);
    ctx.stroke();
    canvas.dataset.dirty = '1';
  }

  function end() {
    drawing = false;
  }

  canvas.addEventListener('mousedown', start);
  canvas.addEventListener('mousemove', move);
  canvas.addEventListener('mouseup', end);
  canvas.addEventListener('mouseleave', end);
  canvas.addEventListener('touchstart', start, { passive: false });
  canvas.addEventListener('touchmove', move, { passive: false });
  canvas.addEventListener('touchend', end);
}

function clearSignatureCanvas(canvas) {
  if (!canvas) return;
  var ctx = canvas.getContext('2d');
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  delete canvas.dataset.dirty;
}
