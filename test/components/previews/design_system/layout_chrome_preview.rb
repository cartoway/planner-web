# frozen_string_literal: true

module DesignSystem
  class LayoutChromePreview < Lookbook::Preview
    layout 'lookbook_preview'

    def cards_and_placeholder
      render_with_template
    end

    def list_group
      render_with_template
    end

    def form_sidebar_chrome
      render_with_template
    end
  end
end
