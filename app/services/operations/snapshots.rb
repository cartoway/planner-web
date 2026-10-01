# frozen_string_literal: true

module Operations
  # Curated jsonb copies. Not a full row dump: only what execution still needs after a wipe.
  # rubocop:disable Metrics/ModuleLength
  module Snapshots
    KIND_BY_TYPE = {
      'StopVisit' => 'visit',
      'StopRest' => 'rest',
      'StopStore' => 'store'
    }.freeze

    module_function

    def kind_for(stop)
      KIND_BY_TYPE.fetch(stop.type) { KIND_BY_TYPE.fetch(stop.class.name, 'visit') }
    end

    # Rest coords come from vehicle_usage.default_store_rest, not stops.store_id.
    def store_for(stop)
      if kind_for(stop) == 'rest'
        stop.position? ? stop.position : nil
      else
        stop.store || stop.store_reload&.store
      end
    end

    def fingerprint(planning, visible_routes_only: false, route_ids: nil)
      scope = Route.unscoped
                   .left_joins(:vehicle_usage)
                   .joins('LEFT JOIN stops ON stops.route_id = routes.id AND stops.active IS DISTINCT FROM FALSE')
                   .where(planning_id: planning.id)
                   .where.not(vehicle_usage_id: nil)
      scope = scope.where(id: route_ids) if route_ids.present?
      scope = scope.where('routes.hidden IS NOT TRUE') if visible_routes_only
      rows = scope
             .order('routes.id', 'stops.index')
             .pluck('routes.id', 'vehicle_usages.vehicle_id', 'stops.id', 'stops.visit_id', 'stops.type', 'stops.index')
      payload = rows.map { |route_id, vehicle_id, stop_id, visit_id, type, index|
        kind = KIND_BY_TYPE[type]
        [route_id, vehicle_id, stop_id, visit_id, kind, index].join(':')
      }.join('|')
      Digest::SHA256.hexdigest(payload)
    end

    def planning(planning)
      {
        'id' => planning.id,
        'name' => planning.name,
        'ref' => planning.ref,
        'date' => planning.date&.to_s,
        'begin_date' => planning.begin_date&.to_s,
        'end_date' => planning.end_date&.to_s,
        'vehicle_usage_set_id' => planning.vehicle_usage_set_id,
        'vehicle_usage_set_name' => planning.vehicle_usage_set&.name
      }
    end

    def deliverable_units(customer)
      customer.deliverable_units.map { |unit|
        {
          'id' => unit.id,
          'ref' => unit.ref,
          'label' => unit.label,
          'icon' => unit.icon,
          'default_delivery' => unit.default_delivery,
          'default_pickup' => unit.default_pickup
        }
      }
    end

    def vehicle(vehicle)
      return {} unless vehicle

      router = vehicle.default_router
      {
        'id' => vehicle.id,
        'name' => vehicle.name,
        'ref' => vehicle.ref,
        'color' => vehicle.color,
        'capacities' => vehicle.capacities || {},
        'phone_number' => vehicle.phone_number,
        'contact_email' => vehicle.contact_email,
        'driver_token_present' => vehicle.driver_token.present?,
        'router_mode' => router&.mode,
        'router_name_locale' => router&.name_locale.presence || {}
      }
    end

    def vehicle_usage(usage)
      return {} unless usage

      {
        'id' => usage.id,
        'vehicle_id' => usage.vehicle_id,
        'active' => usage.active,
        'time_window_start' => schedule_seconds(usage, :time_window_start),
        'time_window_end' => schedule_seconds(usage, :time_window_end),
        'rest_start' => schedule_seconds(usage, :rest_start),
        'rest_stop' => schedule_seconds(usage, :rest_stop),
        'rest_duration' => schedule_seconds(usage, :rest_duration),
        'max_reload' => usage.max_reload,
        'store_start' => place(usage.store_start),
        'store_stop' => place(usage.store_stop),
        'store_rest' => place(usage.default_store_rest)
      }
    end

    def route(route)
      data = route.route_data
      {
        'id' => route.id,
        'ref' => route.ref,
        'hidden' => route.hidden,
        'color' => route.color,
        'distance' => data&.distance,
        'drive_time' => data&.drive_time,
        'visits_duration' => data&.visits_duration,
        'wait_time' => data&.wait_time,
        'rests_duration' => data&.rests_duration,
        'emission' => data&.emission,
        'revenue' => data&.revenue,
        'cost_distance' => data&.cost_distance,
        'cost_fixed' => data&.cost_fixed,
        'cost_time' => data&.cost_time,
        'work_duration' => route.work_duration,
        'duration' => route.total_duration,
        'start' => data && schedule_seconds(data, :start),
        'end' => data && schedule_seconds(data, :end),
        'departure' => data && schedule_seconds(data, :departure),
        'pickups' => data&.pickups || {},
        'deliveries' => data&.deliveries || {},
        'out_of_capacity' => data&.out_of_capacity,
        'out_of_drive_time' => data&.out_of_drive_time,
        'out_of_max_distance' => data&.out_of_max_distance,
        'out_of_max_ride_distance' => data&.out_of_max_ride_distance,
        'out_of_max_ride_duration' => data&.out_of_max_ride_duration,
        'out_of_max_reload' => data&.out_of_max_reload,
        'out_of_relation' => data&.out_of_relation,
        'out_of_skill' => data&.out_of_skill,
        'out_of_window' => data&.out_of_window,
        'out_of_work_time' => data&.out_of_work_time,
        'out_of_force_position' => data&.out_of_force_position,
        'unmanageable_capacity' => data&.unmanageable_capacity,
        'tracks' => tracks_for(route)
      }
    end

    # Encoded route_geojson tracks (precision 6). Not the stop-to-stop shortcut.
    # Drop legs that only serve inactive stops (stale geojson after a deactivate without recompute).
    def tracks_for(route)
      inactive_indices = inactive_stop_indices(route)
      Array(route&.geojson_tracks).filter_map { |raw|
        feature = raw.is_a?(String) ? JSON.parse(raw) : raw
        next unless feature.is_a?(Hash)
        next if track_for_inactive_stop?(feature, inactive_indices)

        geometry = feature['geometry'] || feature[:geometry]
        next unless geometry.is_a?(Hash)

        geometry = geometry.stringify_keys
        next if geometry['polylines'].blank? && Array(geometry['coordinates']).empty?

        {
          'polylines' => geometry['polylines'],
          'coordinates' => geometry['coordinates']
        }.compact
      }
    rescue JSON::ParserError
      []
    end

    def inactive_stop_indices(route)
      Array(route&.stops).each_with_object(Set.new) do |stop, indices|
        indices << stop.index.to_i unless stop.active?
      end
    end

    def track_for_inactive_stop?(feature, inactive_indices)
      return false if inactive_indices.empty?

      props = (feature['properties'] || feature[:properties] || {}).stringify_keys
      indices = Array(props['stop_indices'] || props['stop_index']).compact.map(&:to_i)
      indices.present? && indices.all? { |index| inactive_indices.include?(index) }
    end

    def destination(destination)
      return {} unless destination

      {
        'id' => destination.id,
        'ref' => destination.ref,
        'name' => destination.name,
        'street' => destination.street,
        'postalcode' => destination.postalcode,
        'city' => destination.city,
        'state' => destination.state,
        'country' => destination.country,
        'lat' => destination.lat,
        'lng' => destination.lng,
        'phone_number' => destination.phone_number,
        'email' => destination.email,
        'duration' => schedule_seconds(destination, :duration),
        'detail' => destination.detail,
        'comment' => destination.comment
      }
    end

    def visit(visit, units_by_id)
      return {} unless visit

      {
        'id' => visit.id,
        'ref' => visit.ref,
        'duration' => schedule_seconds(visit, :duration),
        'priority' => visit.priority,
        'force_position' => visit.force_position,
        'revenue' => visit.revenue,
        'time_window_start_1' => schedule_seconds(visit, :time_window_start_1),
        'time_window_end_1' => schedule_seconds(visit, :time_window_end_1),
        'time_window_start_2' => schedule_seconds(visit, :time_window_start_2),
        'time_window_end_2' => schedule_seconds(visit, :time_window_end_2),
        'pickups' => quantities(visit.pickups, units_by_id),
        'deliveries' => quantities(visit.deliveries, units_by_id),
        'custom_attributes' => visit.custom_attributes || {}
      }
    end

    def store(store, store_reload = nil)
      snap = place(store)
      return {} if snap.blank?

      snap['store_reload_id'] = store_reload.id if store_reload
      snap['store_reload_ref'] = store_reload.ref if store_reload
      snap
    end

    # Planned fields only — execution status/eta live on operation_stops columns.
    def stop(stop)
      {
        'id' => stop.id,
        'type' => stop.type,
        'time' => schedule_seconds(stop, :time),
        'loads' => stop.loads || {},
        'custom_attributes' => stop.custom_attributes || {},
        'active' => stop.active,
        'locked' => stop.locked,
        'distance' => stop.distance,
        'drive_time' => stop.drive_time,
        'wait_time' => stop.wait_time,
        'no_path' => stop.no_path,
        'out_of_window' => stop.out_of_window,
        'out_of_capacity' => stop.out_of_capacity,
        'out_of_drive_time' => stop.out_of_drive_time,
        'out_of_work_time' => stop.out_of_work_time,
        'out_of_max_distance' => stop.out_of_max_distance,
        'out_of_force_position' => stop.out_of_force_position,
        'out_of_relation' => stop.out_of_relation,
        'out_of_max_ride_distance' => stop.out_of_max_ride_distance,
        'out_of_max_ride_duration' => stop.out_of_max_ride_duration,
        'out_of_skill' => stop.out_of_skill,
        'out_of_max_reload' => stop.out_of_max_reload,
        'unmanageable_capacity' => stop.unmanageable_capacity
      }
    end

    def quantities(raw, units_by_id)
      hash = raw.respond_to?(:to_h) ? raw.to_h : {}
      hash.each_with_object({}) do |(unit_id, value), out|
        next if value.nil?

        unit = units_by_id[unit_id.to_i]
        out[unit_id.to_s] = {
          'value' => value.to_f,
          'label' => unit&.label,
          'ref' => unit&.ref
        }
      end
    end

    def place(record)
      return {} unless record

      {
        'id' => record.id,
        'ref' => record.try(:ref),
        'name' => record.try(:name),
        'street' => record.try(:street),
        'postalcode' => record.try(:postalcode),
        'city' => record.try(:city),
        'state' => record.try(:state),
        'country' => record.try(:country),
        'lat' => record.try(:lat),
        'lng' => record.try(:lng)
      }.compact
    end

    def schedule_seconds(record, attr)
      raw = record.read_attribute_before_type_cast(attr)
      return raw.to_i if raw.is_a?(Numeric) || raw.to_s.match?(/\A-?\d+\z/)
      return nil if raw.blank?

      value = record.read_attribute(attr)
      return value if value.is_a?(Integer)
      return (value.hour * 3600) + (value.min * 60) + value.sec if value.respond_to?(:hour)

      nil
    end

    def timestamp_on(date, value)
      return nil if value.blank? || date.blank?

      day = date.to_date
      if value.is_a?(Integer)
        return Time.zone.local(day.year, day.month, day.day) + value
      end
      if value.respond_to?(:hour) && value.respond_to?(:min) && value.respond_to?(:sec)
        return Time.zone.local(day.year, day.month, day.day, value.hour, value.min, value.sec)
      end

      parsed = Time.zone.parse(value.to_s)
      return nil unless parsed

      Time.zone.local(day.year, day.month, day.day, parsed.hour, parsed.min, parsed.sec)
    rescue ArgumentError, TypeError
      nil
    end

    # Clock on the operation date. A later calendar day is part of the label.
    def clock_on(date, seconds)
      at = timestamp_on(date, seconds)
      return if at.blank? || date.blank?

      clock = I18n.l(at, format: :hour_minute)
      at.to_date == date.to_date ? clock : "#{I18n.l(at.to_date)} #{clock}"
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
