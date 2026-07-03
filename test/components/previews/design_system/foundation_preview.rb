# frozen_string_literal: true

module DesignSystem
  class FoundationPreview < ApplicationPreview
    def default
      render_with_template
    end

    def typography
      render_with_template
    end

    def color_surfaces
      render_with_template
    end
end
end
