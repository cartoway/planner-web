# frozen_string_literal: true

module DesignSystem
  # Static HTML mirroring v1 planning edit DOM. Styles: v2/_plannings.scss + _lookbook_planning_preview.scss.
  class PlanningSidebarPreview < ApplicationPreview
    def default
      render_with_template
    end
end
end
