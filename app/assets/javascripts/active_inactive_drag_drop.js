// Active/Inactive Drag & Drop Component
// Usage: new ActiveInactiveDragDrop(containerId, options)
class ActiveInactiveDragDrop {
  constructor(containerId, options = {}) {
    this.containerId = containerId;
    this.options = {
      // Container selectors
      activeContainerSelector: '.active-zone .item-list, .priority-active .priority-labels',
      inactiveContainerSelector: '.inactive-zone .item-list, .priority-inactive .priority-labels',

      // Item selectors
      itemSelector: '.draggable-item, .label',

      // Input selectors
      hiddenInputSelector: 'input[name*="priority"]',

      // Display selectors
      orderDisplaySelector: '.item-order, .order',
      textDisplaySelector: '.item-text, .name',

      // Configuration
      minActiveItems: 1,
      orderFormat: 'number', // 'number', 'letter', 'custom'
      inactiveOrderDisplay: '-',

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

    this.container = document.getElementById(containerId);
    if (!this.container) {
      console.error(`Container with id "${containerId}" not found`);
      return;
    }

    this.activeContainer = this.container.querySelector(this.options.activeContainerSelector);
    this.inactiveContainer = this.container.querySelector(this.options.inactiveContainerSelector);

    if (!this.activeContainer || !this.inactiveContainer) {
      console.error('Active or inactive container not found');
      return;
    }

    this.draggedElement = null;
    this.init();
  }

  init() {
    this.makeDraggable();
    this.updateItemOrder();
    this.updateHiddenInputs();
    this.addFormValidation();
    this.addEventListeners();
  }

  addEventListeners() {
    [this.activeContainer, this.inactiveContainer].forEach(container => {
      container.addEventListener('dragstart', this.handleDragStart.bind(this));
      container.addEventListener('dragend', this.handleDragEnd.bind(this));
      container.addEventListener('dragover', this.handleDragOver.bind(this));
      container.addEventListener('dragleave', this.handleDragLeave.bind(this));
      container.addEventListener('drop', this.handleDrop.bind(this));
    });
  }

  updateItemOrder() {
    // Update order for active items
    const activeItems = this.activeContainer.querySelectorAll(this.options.itemSelector);
    activeItems.forEach((item, index) => {
      const orderElement = item.querySelector(this.options.orderDisplaySelector);
      if (orderElement) {
        orderElement.textContent = this.formatOrder(index + 1);
      }
      item.dataset.index = index;

      // Remove inactive class from active items
      item.classList.remove(this.options.inactiveItemClass);
    });

    // Update order for inactive items
    const inactiveItems = this.inactiveContainer.querySelectorAll(this.options.itemSelector);
    inactiveItems.forEach((item, index) => {
      const orderElement = item.querySelector(this.options.orderDisplaySelector);
      if (orderElement) {
        orderElement.textContent = this.options.inactiveOrderDisplay;
      }
      item.dataset.index = index;

      // Add inactive class to inactive items
      item.classList.add(this.options.inactiveItemClass);
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
    const activeItems = this.activeContainer.querySelectorAll(this.options.itemSelector);
    const hiddenInputs = this.container.querySelectorAll(this.options.hiddenInputSelector);

    // Get the input name before removing existing inputs
    const inputName = this.getHiddenInputName();

    // Remove all existing hidden inputs
    hiddenInputs.forEach(input => input.remove());

    // Create new hidden inputs for active items
    activeItems.forEach(item => {
      const value = item.dataset.value || item.dataset.id || item.textContent.trim();
      const hiddenInput = document.createElement('input');
      hiddenInput.type = 'hidden';
      hiddenInput.name = inputName;
      hiddenInput.value = value;
      this.container.appendChild(hiddenInput);
    });

    // Call callback if provided
    if (this.options.onUpdate) {
      this.options.onUpdate(this.getActiveItems(), this.getInactiveItems());
    }
  }

  getHiddenInputName() {
    // Try to find existing input to get the name pattern
    const existingInput = this.container.querySelector(this.options.hiddenInputSelector);
    if (existingInput) {
      return existingInput.name;
    }
    return 'priority[]';
  }

  getActiveItems() {
    return Array.from(this.activeContainer.querySelectorAll(this.options.itemSelector))
      .map(item => ({
        id: item.dataset.id,
        value: item.dataset.value,
        text: item.textContent.trim(),
        element: item
      }));
  }

  getInactiveItems() {
    return Array.from(this.inactiveContainer.querySelectorAll(this.options.itemSelector))
      .map(item => ({
        id: item.dataset.id,
        value: item.dataset.value,
        text: item.textContent.trim(),
        element: item
      }));
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
        const activeItems = this.activeContainer.querySelectorAll(this.options.itemSelector);
        if (activeItems.length < this.options.minActiveItems) {
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

  // Event handlers
  handleDragStart(e) {
    this.draggedElement = e.target;
    e.target.style.opacity = '0.5';
    e.target.classList.add('dragging');
  }

  handleDragEnd(e) {
    e.target.style.opacity = '1';
    e.target.classList.remove('dragging');
    this.draggedElement = null;

    // Clean up all drag-over indicators
    this.container.querySelectorAll(`${this.options.itemSelector}, .${this.options.itemListClass}`).forEach(element => {
      element.classList.remove(this.options.dragOverClass);
    });
  }

  handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';

    const target = e.target.closest(this.options.itemSelector);
    const targetContainer = e.target.closest(`.${this.options.itemListClass}`);

    // Remove drag-over class from all containers
    this.container.querySelectorAll(`.${this.options.itemListClass}`).forEach(container => {
      container.classList.remove(this.options.dragOverClass);
    });

    if (target && target !== this.draggedElement) {
      target.classList.add(this.options.dragOverClass);
    } else if (targetContainer && targetContainer !== this.draggedElement.closest(`.${this.options.itemListClass}`)) {
      // Highlight the container if dropping on empty space
      targetContainer.classList.add(this.options.dragOverClass);
    }
  }

  handleDragLeave(e) {
    const target = e.target.closest(this.options.itemSelector);
    const targetContainer = e.target.closest(`.${this.options.itemListClass}`);

    if (target) {
      target.classList.remove(this.options.dragOverClass);
    }

    // Only remove container highlight if we're leaving the container entirely
    if (targetContainer && !targetContainer.contains(e.relatedTarget)) {
      targetContainer.classList.remove(this.options.dragOverClass);
    }
  }

  handleDrop(e) {
    e.preventDefault();

    const target = e.target.closest(this.options.itemSelector);
    const targetContainer = e.target.closest(`.${this.options.itemListClass}`);
    const draggedContainer = this.draggedElement.closest(`.${this.options.itemListClass}`);

    // Clean up all drag-over indicators
    this.container.querySelectorAll(`${this.options.itemSelector}, .${this.options.itemListClass}`).forEach(element => {
      element.classList.remove(this.options.dragOverClass);
    });

    if (this.draggedElement) {
      // If dropping on an item
      if (target && target !== this.draggedElement) {
        // If moving between containers
        if (targetContainer !== draggedContainer) {
          // Check if we're trying to move to inactive zone and it would leave active zone empty
          if (targetContainer === this.inactiveContainer &&
              draggedContainer === this.activeContainer &&
              this.activeContainer.children.length <= this.options.minActiveItems) {
            // Don't allow moving the last active item to inactive
            return;
          }
          // Move the element to the new container
          targetContainer.appendChild(this.draggedElement);
        } else {
          // Reorder within the same container
          const draggedIndex = parseInt(this.draggedElement.dataset.index);
          const targetIndex = parseInt(target.dataset.index);

          if (draggedIndex < targetIndex) {
            target.parentNode.insertBefore(this.draggedElement, target.nextSibling);
          } else {
            target.parentNode.insertBefore(this.draggedElement, target);
          }
        }
      }
      // If dropping on empty container
      else if (targetContainer && targetContainer !== draggedContainer) {
        // Check if we're trying to move to inactive zone and it would leave active zone empty
        if (targetContainer === this.inactiveContainer &&
            draggedContainer === this.activeContainer &&
            this.activeContainer.children.length <= this.options.minActiveItems) {
          // Don't allow moving the last active item to inactive
          return;
        }
        // Move the element to the empty container
        targetContainer.appendChild(this.draggedElement);
      }

      // Update order numbers and hidden inputs
      this.updateItemOrder();
      this.updateHiddenInputs();
    }
  }

  // Public methods
  refresh() {
    this.makeDraggable();
    this.updateItemOrder();
    this.updateHiddenInputs();
  }

  addItem(itemData, active = true) {
    const item = this.createItemElement(itemData);
    const container = active ? this.activeContainer : this.inactiveContainer;
    container.appendChild(item);
    this.refresh();
  }

  createItemElement(itemData) {
    const item = document.createElement('div');
    item.className = this.options.draggableItemClass;
    item.draggable = true;

    if (itemData.id) item.dataset.id = itemData.id;
    if (itemData.value) item.dataset.value = itemData.value;

    const orderSpan = document.createElement('span');
    orderSpan.className = this.options.orderDisplayClass;
    orderSpan.textContent = this.options.inactiveOrderDisplay;

    const textSpan = document.createElement('span');
    textSpan.className = this.options.textDisplayClass;
    textSpan.textContent = itemData.text || itemData.value || itemData.id;

    item.appendChild(orderSpan);
    item.appendChild(textSpan);

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
function initializeDragDrop(containerId, type = 'generic', options = {}) {
  const defaultOptions = {
    minActiveItems: 1,
    onValidationError: function() {
      return I18n.t(`${type}.form.priority_not_empty`);
    }
  };

  return new ActiveInactiveDragDrop(containerId, { ...defaultOptions, ...options });
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  // Auto-initialize common patterns
  const containers = document.querySelectorAll('[data-drag-drop]');
  containers.forEach(container => {
    const type = container.dataset.dragDrop;
    const options = container.dataset.dragDropOptions ?
      JSON.parse(container.dataset.dragDropOptions) : {};

    initializeDragDrop(container.id, type, options);
  });
});
