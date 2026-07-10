# frozen_string_literal: true

module Lookbook
  # Accept Playwright snapshot baselines from the Lookbook VRT report (dev only).
  class VisualRegressionController < ActionController::Base
    protect_from_forgery with: :exception

    before_action :require_vrt_enabled!

    def accept
      name = Lookbook::VisualRegression::AcceptSnapshot.call!(params.require(:name))
      render json: { ok: true, name: name }
    rescue Lookbook::VisualRegression::AcceptSnapshot::Error => e
      render json: { ok: false, error: e.message }, status: :unprocessable_entity
    end

    def accept_all
      names = Lookbook::VisualRegression::AcceptSnapshot.call_all!
      render json: { ok: true, names: names }
    rescue Lookbook::VisualRegression::AcceptSnapshot::Error => e
      render json: { ok: false, error: e.message }, status: :unprocessable_entity
    end

    private

    def require_vrt_enabled!
      return if Lookbook::VisualRegression.enabled?

      render json: { ok: false, error: 'Visual regression is disabled' }, status: :forbidden
    end
  end
end
