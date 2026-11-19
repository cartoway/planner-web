# frozen_string_literal: true

module Operations
  module MobileUrl
    module_function

    # Path of the operation route mobile page (no URL shortener).
    def path(operation_route)
      return nil unless operation_route

      vehicle = operation_route.vehicle
      return nil if vehicle&.driver_token.blank?

      operation = operation_route.operation
      "/operations/#{operation.id}/routes/#{operation_route.id}/mobile?driver_token=#{vehicle.driver_token}"
    end

    # Absolute long URL (UI, email). Prefer this outside SMS.
    def long_for(operation_route)
      relative = path(operation_route)
      return nil if relative.blank?

      reseller = operation_route.operation.customer.reseller
      "#{reseller.url_protocol}://#{reseller.host}#{relative}"
    end

    # Shortened absolute URL — SMS send only.
    def short_for(operation_route)
      url = long_for(operation_route)
      return nil if url.blank?

      Rails.application.config.url_shortener.shorten(url)
    end
  end
end
