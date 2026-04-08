/**
 * ActiveInactiveDragDrop — multi-column drag-and-drop for active / inactive (and optional middle) lists.
 *
 * Construction: `new ActiveInactiveDragDrop(containerElement | containerId, options)`
 * Auto-init: elements with `[data-drag-drop]` are wired from `initDataDragDropRoots` (Turbolinks + DOMContentLoaded).
 *
 * Required option: `columns` — array of at least 2 entries:
 *   - `containerSelector` (string): querySelector relative to the root container; must resolve to the `.item-list` (or equivalent) host.
 *   - `inputName` (string, optional): name= on generated hidden inputs for non-inactive columns. Omit with no hiddenInputSelector to sync order only.
 *   - `hiddenInputSelector` (string, optional): alternative way to infer input name from existing markup.
 *   - `inactive` (boolean): true → no hidden inputs, order display uses `inactiveOrderDisplay`; does not count toward minActiveItems the same way.
 *   - `toggleTo` (number, optional): 0-based column index for the item “×” button; overrides default next-column / 2-col swap.
 *   - `toggleButtons` (false): hide per-row toggle; call `refresh()` after injecting rows via JS.
 *
 * Other notable options: `minActiveItems`, `itemSelector`, `orderDisplaySelector`, `textDisplaySelector`,
 * `showOrder`, `orderFormat`, `onUpdate`, `onValidationError`, CSS class overrides (`activeZoneClass`, `dragOverClass`, …).
 *
 * Public API: `refresh()`, `addItem(data, active)`, `removeItem(id)`, `getActiveItems()`, `getInactiveItems()`, `destroy()` (partial).
 *
 * Drag/drop handlers live in `active_inactive_drag_drop/drag_handlers_mixin.js`, loaded immediately after this file in application.js.
 */
class ActiveInactiveDragDrop {
  constructor(containerOrId, options = {}) {
    this._initialized = false;
    let root = null;
    if (typeof containerOrId === 'string') {
      this.containerId = containerOrId;
      root = containerOrId ? document.getElementById(containerOrId) : null;
    } else if (containerOrId && containerOrId.nodeType === Node.ELEMENT_NODE) {
      root = containerOrId;
      this.containerId = root.id || '';
    } else {
      this.containerId = '';
      root = null;
    }

    this.options = {
      columns: null,

      // Item selectors
      itemSelector: '.draggable-item, .label',

      // Display selectors
      orderDisplaySelector: '.item-order, .order',
      textDisplaySelector: '.item-text, .name',

      // Configuration
      minActiveItems: 1,
      orderFormat: 'number', // 'number', 'letter', 'custom'
      inactiveOrderDisplay: '-',
      toggleButtons: true,
      // When false, skip numbering badges (active/inactive columns only; order is irrelevant).
      showOrder: true,

      // Callbacks
      onUpdate: null,
      onValidationError: null,

      // CSS classes
      activeZoneClass: 'active-zone',
      inactiveZoneClass: 'inactive-zone',
      itemListClass: 'item-list',
      draggableItemClass: 'draggable-item',
      orderDisplayClass: 'item-order',
      textDisplayClass: 'item-text',
      inactiveItemClass: 'inactive',
      dragOverClass: 'drag-over',

      ...options
    };

    this.container = root;
    if (!this.container) {
      const hint = typeof containerOrId === 'string' ? containerOrId : '(element)';
      console.error(`ActiveInactiveDragDrop: container not found (${hint})`);
      return;
    }

    if (!Array.isArray(this.options.columns) || this.options.columns.length < 2) {
      console.error('ActiveInactiveDragDrop: options.columns must be an array with at least 2 column definitions');
      return;
    }

    this.columnTiers = this._buildColumnTiers();
    if (this.columnTiers.some(t => !t.element)) {
      console.error('ActiveInactiveDragDrop: one or more containerSelector targets were not found inside the root element');
      return;
    }

    this.activeContainer = this.columnTiers.find(t => !t.inactive)?.element || null;
    this.inactiveContainer = this.columnTiers.filter(t => t.inactive).map(t => t.element)[0] || null;

    this.draggedElement = null;
    this.init();
    this._initialized = true;
  }

  /**
   * @returns {{ element: Element, inactive: boolean, inputName: string|null, toggleTo: number|null }[]}
   */
  _buildColumnTiers() {
    return this.options.columns.map(col => {
      const el = this.container.querySelector(col.containerSelector);
      const inactive = Boolean(col.inactive);
      const inputName = col.inputName || this.extractInputNameFromSelector(col.hiddenInputSelector) || null;
      let toggleTo = null;
      if (col.toggleTo !== undefined && col.toggleTo !== null && col.toggleTo !== '') {
        const n = Number(col.toggleTo);
        if (Number.isInteger(n)) {
          toggleTo = n;
        }
      }
      return {
        element: el,
        inactive,
        inputName: inactive ? null : inputName,
        toggleTo
      };
    });
  }

  init() {
    this.makeDraggable();
    if (this.options.toggleButtons !== false) {
      this.addToggleButtons();
    }
    this.updateItemOrder();
    this.updateHiddenInputs();
    this.addFormValidation();
    this.addEventListeners();
  }

  // Add "x" button on each item to cycle through columns (or toggle in 2-column mode)
  addToggleButtons() {
    const items = this.container.querySelectorAll(this.options.itemSelector);
    items.forEach(item => {
      if (item.querySelector('.item-toggle-btn')) return;

      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'item-toggle-btn';
      btn.setAttribute('aria-label', 'Toggle');
      btn.innerHTML = '<i class="fa fa-times fa-fw"></i>';
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.toggleItem(item);
      });
      item.appendChild(btn);
    });
  }

  /** Comma-separated itemSelector values are valid for Element.closest(). */
  _itemSelectorForClosest() {
    return this.options.itemSelector.split(',').map(s => s.trim()).filter(Boolean).join(', ');
  }

  _resolveItemRow(node) {
    if (!node || typeof node.closest !== 'function') {
      return null;
    }
    return node.closest(this._itemSelectorForClosest());
  }

  _queryOrderDisplayElement(item) {
    const parts = this.options.orderDisplaySelector.split(',').map(s => s.trim()).filter(Boolean);
    for (const p of parts) {
      const el = item.querySelector(p);
      if (el) {
        return el;
      }
    }
    return null;
  }

  /** Ensures a visible order index target exists (server markup may omit it). */
  _ensureOrderDisplayElement(item) {
    let el = this._queryOrderDisplayElement(item);
    if (el) {
      return el;
    }
    el = document.createElement('span');
    el.className = `${this.options.orderDisplayClass} order`.replace(/\s+/g, ' ').trim();
    const textAnchor = item.querySelector(this.options.textDisplaySelector);
    if (textAnchor) {
      item.insertBefore(el, textAnchor);
    } else {
      item.insertBefore(el, item.firstChild);
    }
    return el;
  }

  _columnIndexOfItem(item) {
    return this.columnTiers.findIndex(t => t.element.contains(item));
  }

  _isInactiveListElement(listEl) {
    const tier = this.columnTiers.find(t => t.element === listEl);
    return Boolean(tier && tier.inactive);
  }

  /**
   * Default: next column (i+1) % n, or swap for exactly 2 columns.
   * If columns[i].toggleTo is a valid index ≠ i, move there instead.
   */
  _toggleDestinationIndex(fromIdx) {
    const n = this.columnTiers.length;
    const tier = this.columnTiers[fromIdx];
    if (tier.toggleTo != null && Number.isInteger(tier.toggleTo)) {
      const to_index = tier.toggleTo;
      if (to_index >= 0 && to_index < n && to_index !== fromIdx) {
        return to_index;
      }
    }
    if (n === 2) {
      return fromIdx === 0 ? 1 : 0;
    }
    return (fromIdx + 1) % n;
  }

  toggleItem(item) {
    const idx = this._columnIndexOfItem(item);
    if (idx < 0) {
      return;
    }

    const targetIdx = this._toggleDestinationIndex(idx);
    if (targetIdx === idx) {
      return;
    }

    const fromTier = this.columnTiers[idx];
    const targetTier = this.columnTiers[targetIdx];
    const movingToInactive = targetTier.inactive;
    const fromVisible = !fromTier.inactive;
    if (fromVisible && movingToInactive &&
        this.visibleTierItemCount() <= this.options.minActiveItems) {
      return;
    }

    targetTier.element.appendChild(item);
    this.updateItemOrder();
    this.updateHiddenInputs();
  }

  visibleTierItemCount() {
    return this.columnTiers
      .filter(t => !t.inactive)
      .reduce((sum, t) => sum + t.element.querySelectorAll(this.options.itemSelector).length, 0);
  }

  addEventListeners() {
    this.columnTiers.forEach(tier => {
      tier.element.addEventListener('dragstart', this.handleDragStart.bind(this));
      tier.element.addEventListener('dragend', this.handleDragEnd.bind(this));
      tier.element.addEventListener('dragover', this.handleDragOver.bind(this));
      tier.element.addEventListener('dragleave', this.handleDragLeave.bind(this));
      tier.element.addEventListener('drop', this.handleDrop.bind(this));
    });
  }

  updateItemOrder() {
    if (this.options.showOrder === false) {
      const orderSelectors = this.options.orderDisplaySelector.split(',').map(s => s.trim()).filter(Boolean);
      this.columnTiers.forEach(tier => {
        const items = tier.element.querySelectorAll(this.options.itemSelector);
        items.forEach((item, index) => {
          item.dataset.index = index;
          if (tier.inactive) {
            item.classList.add(this.options.inactiveItemClass);
          } else {
            item.classList.remove(this.options.inactiveItemClass);
          }
          orderSelectors.forEach(sel => {
            item.querySelectorAll(sel).forEach(el => {
              el.textContent = '';
              el.style.display = 'none';
              el.setAttribute('aria-hidden', 'true');
            });
          });
        });
      });
      return;
    }

    this.columnTiers.forEach(tier => {
      const items = tier.element.querySelectorAll(this.options.itemSelector);
      if (tier.inactive) {
        items.forEach((item, index) => {
          const orderElement = this._ensureOrderDisplayElement(item);
          orderElement.textContent = this.options.inactiveOrderDisplay;
          orderElement.style.display = '';
          orderElement.removeAttribute('aria-hidden');
          item.dataset.index = index;
          item.classList.add(this.options.inactiveItemClass);
        });
      } else {
        items.forEach((item, index) => {
          const orderElement = this._ensureOrderDisplayElement(item);
          orderElement.textContent = this.formatOrder(index + 1);
          orderElement.style.display = '';
          orderElement.removeAttribute('aria-hidden');
          item.dataset.index = index;
          item.classList.remove(this.options.inactiveItemClass);
        });
      }
    });
  }

  formatOrder(index) {
    switch (this.options.orderFormat) {
      case 'letter':
        return String.fromCharCode(64 + index); // A, B, C, ...
      case 'custom':
        return this.options.orderFormat(index);
      default:
        return index.toString();
    }
  }

  updateHiddenInputs() {
    this.columnTiers.forEach(tier => {
      this._syncTierHiddenInputs(tier);
    });

    if (this.options.onUpdate) {
      this.options.onUpdate(this.getActiveItems(), this.getInactiveItems());
    }
  }

  _syncTierHiddenInputs(tier) {
    const items = tier.element.querySelectorAll(this.options.itemSelector);
    items.forEach(item => {
      item.querySelectorAll('input[type="hidden"]').forEach(h => h.remove());
    });

    if (tier.inactive) {
      return;
    }

    if (!tier.inputName) {
      return;
    }

    items.forEach(item => {
      const value = item.dataset.value || item.dataset.id || item.textContent.trim();
      const hiddenInput = document.createElement('input');
      hiddenInput.type = 'hidden';
      hiddenInput.name = tier.inputName;
      hiddenInput.value = value;
      item.appendChild(hiddenInput);
    });
  }

  extractInputNameFromSelector(selector) {
    if (!selector || typeof selector !== 'string') {
      return null;
    }
    const nameMatch = selector.match(/name\s*=\s*["']([^"']+)["']/);
    return nameMatch && nameMatch[1] ? nameMatch[1] : null;
  }

  _itemsPayload(listElement) {
    return Array.from(listElement.querySelectorAll(this.options.itemSelector)).map(item => {
      const textEl = item.querySelector(this.options.textDisplaySelector);
      return {
        id: item.dataset.id,
        value: item.dataset.value,
        text: textEl ? textEl.textContent.trim() : item.textContent.trim(),
        element: item
      };
    });
  }

  /** All items in non-inactive columns, in column order. */
  getActiveItems() {
    return this.columnTiers
      .filter(t => !t.inactive)
      .flatMap(t => this._itemsPayload(t.element));
  }

  /** All items in inactive columns, in column order. */
  getInactiveItems() {
    return this.columnTiers
      .filter(t => t.inactive)
      .flatMap(t => this._itemsPayload(t.element));
  }

  makeDraggable() {
    const items = this.container.querySelectorAll(this.options.itemSelector);
    items.forEach(item => {
      item.draggable = true;
    });
  }

  addFormValidation() {
    const form = this.container.closest('form');
    if (form) {
      form.addEventListener('submit', (e) => {
        const count = this.visibleTierItemCount();
        if (count < this.options.minActiveItems) {
          e.preventDefault();
          const errorMessage = this.options.onValidationError ?
            this.options.onValidationError() :
            `At least ${this.options.minActiveItems} item(s) must be active`;
          alert(errorMessage);
          return false;
        }
      });
    }
  }

  // Public methods
  refresh() {
    this.makeDraggable();
    if (this.options.toggleButtons !== false) {
      this.addToggleButtons();
    }
    this.updateItemOrder();
    this.updateHiddenInputs();
  }

  addItem(itemData, active = true) {
    const item = this.createItemElement(itemData);
    const tier = active ?
      this.columnTiers.find(t => !t.inactive) :
      this.columnTiers.find(t => t.inactive);
    if (tier) {
      tier.element.appendChild(item);
    }
    this.refresh();
  }

  createItemElement(itemData) {
    const item = document.createElement('div');
    item.className = this.options.draggableItemClass;
    item.draggable = true;

    if (itemData.id) item.dataset.id = itemData.id;
    if (itemData.value) item.dataset.value = itemData.value;

    const orderSpan = document.createElement('span');
    orderSpan.className = `${this.options.orderDisplayClass} order`.replace(/\s+/g, ' ').trim();
    orderSpan.textContent = this.options.inactiveOrderDisplay;

    const textSpan = document.createElement('span');
    textSpan.className = this.options.textDisplayClass;
    textSpan.textContent = itemData.text || itemData.value || itemData.id;

    item.appendChild(orderSpan);
    item.appendChild(textSpan);

    if (this.options.toggleButtons !== false) {
      const toggleBtn = document.createElement('button');
      toggleBtn.type = 'button';
      toggleBtn.className = 'item-toggle-btn';
      toggleBtn.setAttribute('aria-label', 'Toggle');
      toggleBtn.innerHTML = '<i class="fa fa-times fa-fw"></i>';
      toggleBtn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.toggleItem(item);
      });
      item.appendChild(toggleBtn);
    }

    return item;
  }

  removeItem(itemId) {
    const item = this.container.querySelector(`[data-id="${itemId}"]`);
    if (item) {
      item.remove();
      this.refresh();
    }
  }

  destroy() {
    // Remove event listeners if needed
    const form = this.container.closest('form');
    if (form) {
      form.removeEventListener('submit', this.addFormValidation);
    }
  }
}

// Helper function to initialize with common configurations
function initializeDragDrop(containerOrId, type = 'generic', options = {}) {
  const defaultOptions = {
    minActiveItems: 1,
    onValidationError: function() {
      return I18n.t(`${type}.form.priority_not_empty`);
    }
  };

  return new ActiveInactiveDragDrop(containerOrId, { ...defaultOptions, ...options });
}

function parseDragDropOptionsFromDataset(container) {
  const raw = container.dataset.dragDropOptions;
  if (!raw || raw === '') {
    return {};
  }
  try {
    return JSON.parse(raw);
  } catch (e) {
    console.error('ActiveInactiveDragDrop: invalid data-drag-drop-options JSON', e, raw);
    return {};
  }
}

function initDataDragDropRoots() {
  document.querySelectorAll('[data-drag-drop]').forEach(container => {
    if (container._dragDropInstance) return;
    const type = container.dataset.dragDrop || 'generic';
    const options = parseDragDropOptionsFromDataset(container);
    const instance = initializeDragDrop(container, type, options);
    if (instance && instance._initialized) {
      container._dragDropInstance = instance;
    }
  });
}

// Drop cached expando so a restored Turbolinks page re-runs init (toggles / order spans).
document.addEventListener('turbolinks:before-cache', function() {
  document.querySelectorAll('[data-drag-drop]').forEach(el => {
    delete el._dragDropInstance;
  });
});

// Initialize when Turbolinks loads (and once on first paint if the event already ran).
document.addEventListener('turbolinks:load', initDataDragDropRoots);
document.addEventListener('DOMContentLoaded', initDataDragDropRoots);
