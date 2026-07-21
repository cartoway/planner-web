# frozen_string_literal: true

module DesignSystem
  class OverlaysPreview < ApplicationPreview
    def modal
      render_with_template
    end

    def dropdown
      render_with_template
    end

    def offcanvas
      render_with_template
    end

    def searchable_checklist_dropdown
      render_with_template.merge(
        assigns: {
          items: searchable_checklist_items,
          default_active_ids: %w[name street city ref geocoding],
          max_active: 5
        }
      )
    end

    private

    def searchable_checklist_items
      [
        { id: 'name', label: 'Name', checked: true },
        { id: 'street', label: 'Street', checked: true },
        { id: 'city', label: 'City', checked: true },
        { id: 'postalcode', label: 'Postal code', checked: false },
        { id: 'ref', label: 'Reference', checked: true },
        { id: 'geocoding', label: 'Geocoding', checked: true },
        { id: 'comment', label: 'Comment', checked: false },
        { id: 'phone', label: 'Phone', checked: false },
        { id: 'tags', label: 'Tags', checked: false },
        { id: 'visit_ref', label: 'Visit ref', checked: false },
        { id: 'duration', label: 'Duration', checked: false },
        { id: 'priority', label: 'Priority', checked: false }
      ]
    end
  end
end
