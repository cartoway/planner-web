# frozen_string_literal: true

module DesignSystem
  # Latest Playwright snapshot comparison (devcontainer / local VRT).
  class VisualRegressionPreview < ApplicationPreview
    def report
      routes = Rails.application.routes.url_helpers
      render_with_template.merge(
        assigns: {
          report: Lookbook::VisualRegression::Report.load,
          vrt_enabled: Lookbook::VisualRegression.enabled?,
          # Lookbook preview URL helpers prefix /lookbook; use main-app routes to avoid doubling.
          accept_url: routes.lookbook_visual_regression_accept_path,
          accept_all_url: routes.lookbook_visual_regression_accept_all_path
        }
      )
    end
  end
end
