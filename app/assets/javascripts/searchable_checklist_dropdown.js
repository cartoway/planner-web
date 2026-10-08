// Copyright © Cartoway
// Bootstrap 3 searchable checklist dropdown: search + global actions + checkboxes.
// Keeps the menu open while interacting (BS3 otherwise closes on any click).
'use strict';

function selectedValues($root) {
  return $root.find('.searchable-checklist-dropdown-checkbox:enabled:checked').map(function() {
    return String(this.value);
  }).get();
}

function syncLabel($root) {
  var count = selectedValues($root).length;
  var $label = $root.find('[data-searchable-checklist-label]');
  if (!$label.length) return;
  if (count === 0) $label.text($root.data('none-label') || '');
  else if (count === 1) $label.text('1 ' + ($root.data('one-label') || ''));
  else $label.text(count + ' ' + ($root.data('many-label') || ''));
}

function filteredCheckboxes($root) {
  return $root.find('.searchable-checklist-dropdown-checkbox:enabled').filter(function() {
    var $option = $(this).closest('.searchable-checklist-dropdown-option');
    return !$option.length || !$option.prop('hidden');
  });
}

function selectedTagIds($root) {
  return $root.find('[data-searchable-checklist-tag-filter]:checked').map(function() {
    return String(this.value);
  }).get();
}

function optionTagIds($option) {
  return String($option.attr('data-tag-ids') || '').split(',').map(function(id) {
    return String(id).trim();
  }).filter(Boolean);
}

function applyFilter($root) {
  var $input = $root.find('[data-searchable-checklist-filter]');
  var query = String($input.val() || '').trim().toLowerCase();
  var tags = selectedTagIds($root);
  $root.find('.searchable-checklist-dropdown-option').each(function() {
    var $option = $(this);
    if ($option.attr('data-unavailable') === 'true') {
      $option.prop('hidden', true);
      return;
    }
    var label = String($option.data('filter-label') || '');
    var nameMatch = query.length === 0 || label.indexOf(query) !== -1;
    var tagMatch = tags.length === 0 || tags.some(function(tagId) {
      return optionTagIds($option).indexOf(tagId) !== -1;
    });
    $option.prop('hidden', !(nameMatch && tagMatch));
  });
  $root.find('[data-searchable-checklist-clear]').toggleClass('hidden', query.length === 0);
  $root.find('.searchable-checklist-dropdown-tag').each(function() {
    var $label = $(this);
    $label.toggleClass('is-active', $label.find('[data-searchable-checklist-tag-filter]').prop('checked'));
  });
}

function setOpen($root, open) {
  var wasOpen = $root.hasClass('open');
  $root.toggleClass('open', !!open);
  $root.find('[data-searchable-checklist-toggle]').attr('aria-expanded', open ? 'true' : 'false');
  if (open) {
    var $input = $root.find('[data-searchable-checklist-filter]');
    if ($input.length) setTimeout(function() { $input.trigger('focus'); }, 0);
    if (!wasOpen) $root.trigger('searchable-checklist-dropdown:open');
  } else if (wasOpen) {
    $root.trigger('searchable-checklist-dropdown:close');
  }
}

function dispatchChange($root) {
  $root.trigger('searchable-checklist-dropdown:change', {
    checkedValues: selectedValues($root),
    checkedCount: selectedValues($root).length
  });
}

function applyAction($root, mode, options) {
  options = options || {};
  filteredCheckboxes($root).each(function() {
    var $box = $(this);
    if (typeof options.applyBox === 'function') {
      options.applyBox($box, mode);
      return;
    }
    if (mode === 'all') $box.prop('checked', true);
    else if (mode === 'clear') $box.prop('checked', false);
    else if (mode === 'reverse') $box.prop('checked', !$box.prop('checked'));
  });
  syncLabel($root);
  dispatchChange($root);
}

export function initSearchableChecklistDropdown(root, options) {
  var $root = root && root.jquery ? root : $(root);
  if (!$root.length) return null;
  options = options || {};
  var ns = '.searchableChecklistDropdown' + ($root.attr('id') ? '-' + $root.attr('id') : '');

  $root.off(ns);
  $(document).off(ns);

  $root.on('click' + ns, '[data-searchable-checklist-toggle]', function(event) {
    event.preventDefault();
    event.stopPropagation();
    setOpen($root, !$root.hasClass('open'));
  });

  // Keep open while interacting inside the menu (search, checkboxes, global actions).
  $root.on('click' + ns, '[data-searchable-checklist-menu]', function(event) {
    event.stopPropagation();
  });

  $root.on('input' + ns, '[data-searchable-checklist-filter]', function() {
    applyFilter($root);
  });

  $root.on('change' + ns, '[data-searchable-checklist-tag-filter]', function() {
    applyFilter($root);
  });

  $root.on('click' + ns, '[data-searchable-checklist-clear]', function(event) {
    event.preventDefault();
    event.stopPropagation();
    $root.find('[data-searchable-checklist-filter]').val('');
    applyFilter($root);
  });

  $root.on('click' + ns, '[data-searchable-checklist-action]', function(event) {
    event.preventDefault();
    event.stopPropagation();
    // Prefer attr: jQuery .data() camelCase is brittle with multi-hyphen keys.
    var mode = $(this).attr('data-searchable-checklist-action');
    applyAction($root, mode, options);
  });

  $root.on('change' + ns, '.searchable-checklist-dropdown-checkbox', function() {
    syncLabel($root);
    dispatchChange($root);
  });

  // Close only on outside clicks (do not rely solely on stopPropagation).
  $(document).on('click' + ns, function(event) {
    if (!$root.hasClass('open')) return;
    if ($(event.target).closest($root).length) return;
    setOpen($root, false);
  });

  syncLabel($root);
  applyFilter($root);

  return {
    root: $root,
    values: function() { return selectedValues($root); },
    setValues: function(ids) {
      var wanted = {};
      (ids || []).forEach(function(id) { wanted[String(id)] = true; });
      $root.find('.searchable-checklist-dropdown-checkbox').each(function() {
        var $box = $(this);
        if ($box.prop('disabled')) return;
        $box.prop('checked', !!wanted[String($box.val())]);
      });
      syncLabel($root);
      dispatchChange($root);
    },
    setDisabled: function(id, disabled) {
      var $box = $root.find('.searchable-checklist-dropdown-checkbox').filter(function() {
        return String(this.value) === String(id);
      });
      $box.prop('disabled', !!disabled);
      if (disabled) $box.prop('checked', false);
      syncLabel($root);
    },
    setItemData: function(id, data) {
      var $option = $root.find('.searchable-checklist-dropdown-option').filter(function() {
        return String($(this).data('item-id')) === String(id);
      });
      if (!$option.length) return;
      Object.keys(data || {}).forEach(function(key) {
        $option.attr('data-' + key.replace(/_/g, '-'), data[key]).data(key, data[key]);
        $option.find('.searchable-checklist-dropdown-checkbox')
          .attr('data-' + key.replace(/_/g, '-'), data[key])
          .data(key, data[key]);
      });
    },
    setItemVisible: function(id, visible) {
      var $option = $root.find('.searchable-checklist-dropdown-option').filter(function() {
        return String($(this).data('item-id')) === String(id);
      });
      if (!$option.length) return;
      $option.attr('data-unavailable', visible ? 'false' : 'true');
      if (!visible) {
        $option.prop('hidden', true);
        $option.find('.searchable-checklist-dropdown-checkbox').prop('checked', false);
        syncLabel($root);
      } else {
        applyFilter($root);
      }
    },
    syncLabel: function() { syncLabel($root); },
    close: function() { setOpen($root, false); },
    destroy: function() {
      $root.off(ns);
      $(document).off(ns);
    }
  };
}

export function initAllSearchableChecklistDropdowns(options) {
  return $('[data-searchable-checklist-dropdown]').map(function() {
    return initSearchableChecklistDropdown(this, options);
  }).get();
}
