# frozen_string_literal: true

module DesignSystem
  class NavigationPreview < ApplicationPreview
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
