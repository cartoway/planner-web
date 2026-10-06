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
      # Demo keeps the full trail so the map stays usable while the job ticks.
      unless operation.customer.vehicle_position_keep_trace? || source.to_s == 'demo'
        operation_route.vehicle_positions.where.not(id: position.id).delete_all
      end

      broadcast_vehicle_pin(operation, position)
      position
    end
    # rubocop:enable Metrics/ParameterLists

    def self.broadcast_vehicle_pin(operation, position)
      Turbo::StreamsChannel.broadcast_stream_to(
        operation,
        content: format(
          '<turbo-stream action="refresh_vehicle" target="map" data-operation-route-id="%<id>d" data-lng="%<lng>f" data-lat="%<lat>f"></turbo-stream>',
          id: position.operation_route_id,
          lng: position.lng,
          lat: position.lat
        )
      )
    rescue StandardError => e
      Rails.logger.warn("vehicle position turbo refresh failed: #{e.class}: #{e.message}")
    end
    private_class_method :broadcast_vehicle_pin
  end
end
