# frozen_string_literal: true

module DesignSystem
  class NavigationPreview < Lookbook::Preview
    layout 'lookbook_preview'

    def breadcrumbs
      render_with_template
    end

    def tabs
      render_with_template
    end

    def pagination
      render_with_template
    end
  end
end
