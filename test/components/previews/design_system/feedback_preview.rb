# frozen_string_literal: true

module DesignSystem
  class FeedbackPreview < ApplicationPreview
    def alerts
      render_with_template
    end

    def badges_and_pills
      render_with_template
    end

    def progress_and_spinners
      render_with_template
    end
  end
end
