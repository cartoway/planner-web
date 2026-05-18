# frozen_string_literal: true

module DesignSystem
  class OverlaysPreview < Lookbook::Preview
    layout 'lookbook_preview'

    def modal
      render_with_template
    end

    def dropdown
      render_with_template
    end

    def offcanvas
      render_with_template
    end
  end
end
