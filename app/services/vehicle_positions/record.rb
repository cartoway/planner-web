# frozen_string_literal: true

module VehiclePositions
  class Record
    class MissingPositionedAt < StandardError; end
    class OperationNotOpen < StandardError; end

    # rubocop:disable Metrics/ParameterLists
    def self.call(operation_route:, lat:, lng:, positioned_at:, source: 'mobile', heading: nil, speed: nil, accuracy: nil, altitude: nil, payload: {})
      raise MissingPositionedAt if positioned_at.blank?

      operation = operation_route.operation
      raise OperationNotOpen unless operation.open?

      position = VehiclePosition.create!(
        customer_id: operation.customer_id,
        vehicle_id: operation_route.vehicle_id,
        operation_id: operation.id,
        operation_route: operation_route,
        lat: lat,
        lng: lng,
        heading: heading,
        speed: speed,
        accuracy: accuracy,
        altitude: altitude,
        positioned_at: positioned_at,
        received_at: Time.current,
        source: source.presence || 'mobile',
        payload: payload || {}
      )

      # Live-only mode: keep the latest point, drop the rest for this route.
      unless operation.customer.vehicle_position_keep_trace?
        operation_route.vehicle_positions.where.not(id: position.id).delete_all
      end

      position
    end
    # rubocop:enable Metrics/ParameterLists
  end
end
