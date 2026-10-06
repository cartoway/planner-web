# frozen_string_literal: true

module Operations
  module MobileUrl
    module_function

    # Shortened absolute URL of the operation route mobile page.
    def for(operation_route)
      return nil unless operation_route

      vehicle = operation_route.vehicle
      return nil if vehicle&.driver_token.blank?

      operation = operation_route.operation
      reseller = operation.customer.reseller
      path = "/operations/#{operation.id}/routes/#{operation_route.id}/mobile?driver_token=#{vehicle.driver_token}"
      url = "#{reseller.url_protocol}://#{reseller.host}#{path}"
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
