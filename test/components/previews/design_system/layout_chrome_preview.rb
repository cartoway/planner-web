# frozen_string_literal: true

module DesignSystem
  class LayoutChromePreview < ApplicationPreview
    def cards_and_placeholder
      render_with_template
    end

    def list_group
      render_with_template
    end

    def form_sidebar_chrome
      render_with_template
    end

    # Mobile (< lg): form panel as bottom sheet + backdrop (same pattern as operation-detail).
    def form_sidebar_bottom_sheet
      render_with_template
    end

    def xl_floating_button
      render_with_template
    end
  end
end
