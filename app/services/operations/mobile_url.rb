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

    # Shortened absolute URL of the operation route mobile page (mail / SMS).
    def for(operation_route)
      relative = path(operation_route)
      return nil if relative.blank?

      reseller = operation_route.operation.customer.reseller
      url = "#{reseller.url_protocol}://#{reseller.host}#{relative}"
      Rails.application.config.url_shortener.shorten(url)
    end

    def for_planning_route(route)
      vehicle = route&.vehicle_usage&.vehicle
      return nil if vehicle&.driver_token.blank?

      operation_route = OperationRoute.joins(:operation)
                                      .where(route_id: route.id, operations: { status: Operation::OPEN_STATUSES })
                                      .order('operations.published_at DESC')
                                      .first
      self.for(operation_route)
    end
  end
end
