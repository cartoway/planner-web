# frozen_string_literal: true

module DesignSystem
  # Documents native range, checkboxes, and switch toggles for v2 (see v2/_form_checks_range.scss).
  class RangeAndChecksPreview < Lookbook::Preview
    layout 'lookbook_preview'

    def range_inputs
      render_with_template
    end

    def basic_checkboxes
      render_with_template
    end

    def toggle_switches
      render_with_template
    end
  end
end
