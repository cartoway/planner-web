// Mixed into ActiveInactiveDragDrop.prototype; must load after utils/active_inactive_drag_drop (see application.js manifest order).
// Keeps drag/drop event handling in one place for easier review.

Object.assign(ActiveInactiveDragDrop.prototype, {
  handleDragStart(e) {
    const item = this._resolveItemRow(e.target);
    if (!item) {
      return;
    }
    this.draggedElement = item;
    item.style.opacity = '0.5';
    item.classList.add('dragging');
  },

  handleDragEnd(e) {
    const hadActiveDrag = this.draggedElement != null;
    const item = this._resolveItemRow(e.target) || this.draggedElement;
    if (item) {
      item.style.opacity = '1';
      item.classList.remove('dragging');
    }
    this.draggedElement = null;

    this.container.querySelectorAll(`${this.options.itemSelector}, .${this.options.itemListClass}`).forEach(element => {
      element.classList.remove(this.options.dragOverClass);
    });

    if (hadActiveDrag) {
      this.updateItemOrder();
      this.updateHiddenInputs();
    }
  },

  handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';

    const target = e.target.closest(this.options.itemSelector);
    const targetContainer = e.target.closest(`.${this.options.itemListClass}`);

    this.container.querySelectorAll(`.${this.options.itemListClass}`).forEach(container => {
      container.classList.remove(this.options.dragOverClass);
    });

    if (target && target !== this.draggedElement) {
      target.classList.add(this.options.dragOverClass);
    } else if (targetContainer && targetContainer !== this.draggedElement.closest(`.${this.options.itemListClass}`)) {
      targetContainer.classList.add(this.options.dragOverClass);
    }
  },

  handleDragLeave(e) {
    const target = e.target.closest(this.options.itemSelector);
    const targetContainer = e.target.closest(`.${this.options.itemListClass}`);

    if (target) {
      target.classList.remove(this.options.dragOverClass);
    }

    if (targetContainer && !targetContainer.contains(e.relatedTarget)) {
      targetContainer.classList.remove(this.options.dragOverClass);
    }
  },

  handleDrop(e) {
    e.preventDefault();

    if (!this.draggedElement) {
      return;
    }

    const target = e.target.closest(this.options.itemSelector);
    const targetContainer = e.target.closest(`.${this.options.itemListClass}`);
    const draggedContainer = this.draggedElement.closest(`.${this.options.itemListClass}`);

    this.container.querySelectorAll(`${this.options.itemSelector}, .${this.options.itemListClass}`).forEach(element => {
      element.classList.remove(this.options.dragOverClass);
    });

    if (target && target !== this.draggedElement) {
      if (targetContainer !== draggedContainer) {
        if (this._isInactiveListElement(targetContainer) &&
            this.wouldViolateMinActiveAfterMoveToInactive(draggedContainer)) {
          return;
        }
        targetContainer.appendChild(this.draggedElement);
      } else {
        const draggedIndex = parseInt(this.draggedElement.dataset.index, 10);
        const targetIndex = parseInt(target.dataset.index, 10);

        if (!Number.isNaN(draggedIndex) && !Number.isNaN(targetIndex)) {
          if (draggedIndex < targetIndex) {
            target.parentNode.insertBefore(this.draggedElement, target.nextSibling);
          } else {
            target.parentNode.insertBefore(this.draggedElement, target);
          }
        }
      }
    } else if (targetContainer && targetContainer !== draggedContainer) {
      if (this._isInactiveListElement(targetContainer) &&
          this.wouldViolateMinActiveAfterMoveToInactive(draggedContainer)) {
        return;
      }
      targetContainer.appendChild(this.draggedElement);
    }

    this.updateItemOrder();
    this.updateHiddenInputs();
  },

  wouldViolateMinActiveAfterMoveToInactive(draggedContainer) {
    if (this.options.minActiveItems <= 0) {
      return false;
    }
    const fromTier = this.columnTiers.find(t => t.element === draggedContainer);
    if (!fromTier || fromTier.inactive) {
      return false;
    }
    return this.visibleTierItemCount() <= this.options.minActiveItems;
  }
});
