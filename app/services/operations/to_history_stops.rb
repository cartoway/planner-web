# frozen_string_literal: true

module Operations
  # Build history_stops rows from an operation. Execution status comes from op columns only.
  class ToHistoryStops
    ROUTE_JSON_KEYS = %w[ref hidden color].freeze
    ROUTE_DATA_KEYS = %w[
      distance emission cost_distance cost_fixed cost_time revenue
      start end drive_time wait_time visits_duration rests_duration
      pickups deliveries departure
      out_of_capacity out_of_drive_time out_of_max_distance out_of_max_ride_distance
      out_of_max_ride_duration out_of_max_reload out_of_relation out_of_skill
      out_of_window out_of_work_time out_of_force_position unmanageable_capacity
    ].freeze

    def self.rows(operation, hourly: true, at: Time.current, schema_version: nil)
      new(operation, hourly: hourly, at: at, schema_version: schema_version).rows
    end

    def initialize(operation, hourly:, at:, schema_version:)
      @operation = operation
      @hourly = hourly
      @at = at
      @schema_version = schema_version || self.class.current_schema_version
      @customer = operation.customer
    end

    def rows
      routes = @operation.operation_routes.to_a
      routes = routes.reject(&:unassigned)
      routes.filter_map { |operation_route| row_for(operation_route) }
    end

    def self.current_schema_version
      ActiveRecord::Base.connection.select_value('SELECT max(version) FROM schema_migrations')
    end

    private

    def row_for(operation_route)
      planning_id = @operation.planning_id || @operation.planning_snapshot&.[]('id')
      route_id = operation_route.route_id || operation_route.route_snapshot&.[]('id')
      return if planning_id.blank? || route_id.blank?

      stops = ordered_stops(operation_route)
      snap = operation_route.route_snapshot || {}

      {
        schema_version: @schema_version.to_s,
        date: history_date,
        reseller_id: @customer.reseller_id,
        customer_id: @customer.id,
        vehicle_usage_id: operation_route.vehicle_usage_id || operation_route.vehicle_usage_snapshot&.[]('id'),
        vehicle_id: operation_route.vehicle_id || operation_route.vehicle_snapshot&.[]('id'),
        router_mode: operation_route.vehicle_snapshot&.[]('router_mode'),
        planning_id: planning_id.to_i,
        route_id: route_id.to_i,
        vehicle_usage: strip_ids(operation_route.vehicle_usage_snapshot),
        vehicle: strip_ids(operation_route.vehicle_snapshot),
        planning: strip_ids(@operation.planning_snapshot),
        route: snap.slice(*ROUTE_JSON_KEYS),
        stops: stops_payload(stops),
        stops_count: stops.size,
        stops_active_count: stops.count { |stop| stop.active && operation_route.vehicle_id.present? },
        route_data: snap.slice(*ROUTE_DATA_KEYS),
        start_route_data: {
          'status' => operation_route.departure_status,
          'eta' => operation_route.departure_eta
        }.compact,
        stop_route_data: {
          'status' => operation_route.arrival_status,
          'eta' => operation_route.arrival_eta
        }.compact
      }
    end

    def ordered_stops(operation_route)
      operation_route.operation_stops.sort_by { |stop| stop.index || 0 }
    end

    def stops_payload(stops)
      return nil if stops.empty?

      stops.map { |stop|
        planned = (stop.stop_snapshot || {}).except('status', 'eta', 'status_updated_at')
        {
          'stop' => planned.merge(
            'index' => stop.index,
            'active' => stop.active,
            'status' => stop.status,
            'eta' => stop.eta,
            'status_updated_at' => stop.status_updated_at
          ).compact,
          'visit' => stop.visit_snapshot.presence,
          'destination' => stop.destination_snapshot.presence || stop.store_snapshot.presence
        }.compact
      }
    end

    def history_date
      @hourly ? @at.beginning_of_hour : @at
    end

    def strip_ids(snapshot)
      return {} if snapshot.blank?

      snapshot.except('id')
    end
  end
end
