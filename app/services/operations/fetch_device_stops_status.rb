# frozen_string_literal: true

module Operations
  # Pull telematics stop status/quantities into OperationStop (source of truth).
  # Device adapters keep returning { order_id:, status:, eta:, deliveries:, update_quantities: }.
  class FetchDeviceStopsStatus
    def self.call(operation:)
      new(operation).call
    end

    def initialize(operation)
      @operation = operation
      @customer = operation.customer
    end

    def call
      return [] unless @customer.device.available_stop_status?

      stops_map = build_stops_map
      return [] if stops_map.empty?

      rows = fetch_device_rows
      rows.each { |row| apply_row(stops_map, row) }
      rows
    end

    private

    def build_stops_map
      map = {}
      @operation.operation_stops.active_sync.find_each do |operation_stop|
        map["v#{operation_stop.visit_id}"] = operation_stop if operation_stop.visit_id
        map["r#{operation_stop.stop_id}"] = operation_stop if operation_stop.stop_id
      end
      map
    end

    def fetch_device_rows
      date = device_date
      planning = @operation.planning

      Planner::Application.config.devices.each_pair.flat_map { |key, device|
        next unless device.respond_to?(:fetch_stops) && @customer.device.configured?(key)

        rows = begin
          device.fetch_stops(@customer, date, planning)
        rescue StandardError
          nil
        end
        Array(rows)
      }.compact.reject { |row| DeviceBase.is_a_store?(row[:order_id]) }
    end

    def device_date
      date = @operation.planning&.date || @operation.date
      date.beginning_of_day
    end

    def apply_row(stops_map, row)
      operation_stop = stops_map[row[:order_id].to_s]
      return unless operation_stop

      apply_quantities(operation_stop, row) if row[:update_quantities] && row[:deliveries].is_a?(Array)

      return if row[:status].blank? && row[:eta].blank?

      OperationStops::RecordStatus.call(
        operation_stop: operation_stop,
        status: row[:status],
        eta: row[:eta],
        recorded_at: Time.zone.now,
        source: 'device',
        source_ref: row[:order_id].to_s,
        payload: row.slice(:update_quantities).compact
      )
    rescue ArgumentError
      # e.g. clearing transferred — skip this row
      nil
    end

    def apply_quantities(operation_stop, row)
      du_by_label = @customer.deliverable_units.each_with_object({}) { |du, acc| acc[du.label] = du.id }
      deliveries = {}
      row[:deliveries].each do |delivery|
        unit_id = du_by_label[delivery[:label]]
        next unless unit_id

        value = Float(delivery[:delivery], exception: false)
        deliveries[unit_id.to_s] = value if value
      end
      return if deliveries.empty?

      stored = (operation_stop.actual_quantities || {}).deep_dup
      stored['deliveries'] = (stored['deliveries'] || {}).merge(deliveries)
      operation_stop.update!(actual_quantities: stored)
    end
  end
end
