# frozen_string_literal: true

module DesignSystem
  # Static HTML mirroring v1 planning edit DOM (`plannings/_edit`, `_selector`, `_sidebar`, routes panels).
  # Styles: `v2/_plannings.scss` + `v2/_lookbook_planning_preview.scss` (via `lookbook_preview.scss`).
  class PlanningSidebarPreview < Lookbook::Preview
    layout 'lookbook_preview'

    def default
      render_with_template
    end
  end
end
