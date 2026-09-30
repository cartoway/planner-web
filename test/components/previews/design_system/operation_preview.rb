# frozen_string_literal: true

module DesignSystem
  # Static desk mirroring operations/show. Styles: v2/_operations.scss and v2/_visual_language.scss.
  class OperationPreview < ApplicationPreview
    def default
      render_with_template
    end

    def media
      render_with_template
    end
  end
end
