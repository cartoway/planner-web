# frozen_string_literal: true

module VehiclePositions
  class Record
    class MissingPositionedAt < StandardError; end
    class OperationNotOpen < StandardError; end

    # Some WebViews report "unknown" sensors as ±Number.MAX_VALUE, which overflows
    # PostgreSQL double precision and surfaces as ActionController 422 (StatementInvalid).
    ALTITUDE_RANGE = (-1000.0..20_000.0) # metres
    ACCURACY_RANGE = (0.0..100_000.0) # metres CEP
    SPEED_RANGE = (0.0..1_000.0) # m/s
    HEADING_RANGE = (0.0..360.0) # degrees

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
        heading: sane_sensor(heading, HEADING_RANGE),
        speed: sane_sensor(speed, SPEED_RANGE),
        accuracy: sane_sensor(accuracy, ACCURACY_RANGE),
        altitude: sane_sensor(altitude, ALTITUDE_RANGE),
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
      accuracy_attr = position.accuracy.present? ? %( data-accuracy="#{position.accuracy}") : ''
      Turbo::StreamsChannel.broadcast_stream_to(
        operation,
        content: format(
          '<turbo-stream action="refresh_vehicle" target="map" data-operation-route-id="%<id>d" data-lng="%<lng>f" data-lat="%<lat>f"%<accuracy>s></turbo-stream>',
          id: position.operation_route_id,
          lng: position.lng,
          lat: position.lat,
          accuracy: accuracy_attr
        )
      )
    rescue StandardError => e
      Rails.logger.warn("vehicle position turbo refresh failed: #{e.class}: #{e.message}")
    end
    private_class_method :broadcast_vehicle_pin

    def self.sane_sensor(value, range)
      return nil if value.nil?

      float = Float(value)
      return nil unless float.finite?
      return nil unless range.cover?(float)

      float
    rescue ArgumentError, TypeError
      nil
    end
    private_class_method :sane_sensor
  end
end
