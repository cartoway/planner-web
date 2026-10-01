# frozen_string_literal: true

module Operations
  class RouteConflict < StandardError
    attr_reader :route_ids

    def initialize(route_ids)
      @route_ids = Array(route_ids)
      super(I18n.t('execution.route_conflict'))
    end
  end

  class EmptyRoutes < StandardError; end

  class PublishFromPlanning
    def self.call(planning:, date: nil, name: nil, route_ids: nil, visible_routes_only: false)
      new(planning, date, name, route_ids, visible_routes_only).call
    end

    def initialize(planning, date = nil, name = nil, route_ids = nil, visible_routes_only = false)
      @planning = planning
      @date = date
      @name = name
      @route_ids = route_ids&.map(&:to_i)&.uniq
      @visible_routes_only = visible_routes_only
    end

    def call
      Operation.transaction do
        selected = selected_routes
        raise EmptyRoutes if selected.empty?

        date = chosen_date
        conflict_ids = conflicting_route_ids(selected.map(&:id), date)
        raise RouteConflict, conflict_ids if conflict_ids.any?

        build(selected, date)
      end
    end

    private

    def selected_routes
      routes = routes_for(@planning).select { |route| route.vehicle_usage_id.present? }
      routes = routes.reject(&:hidden) if @visible_routes_only
      if @route_ids
        wanted = @route_ids.to_set
        routes = routes.select { |route| wanted.include?(route.id) }
      end
      routes
    end

    def conflicting_route_ids(ids, date)
      taken = @planning.taken_route_ids(date: date).to_set
      ids.select { |id| taken.include?(id) }
    end

    def build(selected, date)
      units = @planning.customer.deliverable_units.to_a
      units_by_id = units.index_by(&:id)
      selected_ids = selected.map(&:id)
      attrs = {}
      attrs['_visible_routes_only'] = true if @visible_routes_only
      attrs['_route_ids'] = selected_ids if @route_ids || @visible_routes_only

      operation = Operation.create!(
        customer: @planning.customer,
        planning: @planning,
        date: date,
        name: @name.presence || @planning.name,
        ref: unique_ref(date),
        status: 'in_progress',
        published_at: Time.current,
        synced_at: Time.current,
        structure_fingerprint: Snapshots.fingerprint(
          @planning,
          visible_routes_only: @visible_routes_only,
          route_ids: selected_ids
        ),
        planning_snapshot: Snapshots.planning(@planning),
        deliverable_units_snapshot: Snapshots.deliverable_units(@planning.customer),
        custom_attributes: attrs
      )
      selected.each_with_index do |route, index|
        build_route(operation, route, index, false, date, units_by_id, copy_cursor: false, with_stops: true)
      end
      OperationDeliveryTracking.ensure_for!(operation)
      operation
    end

    def build_route(operation, route, index, unassigned, date, units_by_id, copy_cursor:, with_stops: true)
      vehicle = route.vehicle_usage&.vehicle
      departure_status, departure_eta = leg(route.start_route_data, route.try(:departure_eta), date)
      arrival_status, arrival_eta = leg(route.stop_route_data, route.try(:arrival_eta), date)
      arrival_status ||= route.arrival_status
      OperationRoute.create!(
        operation: operation,
        route: route,
        vehicle_usage: route.vehicle_usage,
        vehicle: vehicle,
        index: index,
        ref: route.ref,
        color: route.color.presence || vehicle&.color,
        hidden: route.hidden || false,
        unassigned: unassigned,
        sync_state: 'active',
        vehicle_snapshot: Snapshots.vehicle(vehicle),
        vehicle_usage_snapshot: Snapshots.vehicle_usage(route.vehicle_usage),
        route_snapshot: Snapshots.route(route),
        departure_status: copy_cursor ? departure_status : nil,
        departure_eta: copy_cursor ? departure_eta : nil,
        arrival_status: copy_cursor ? arrival_status : nil,
        arrival_eta: copy_cursor ? arrival_eta : nil,
        last_sent_at: copy_cursor ? route.last_sent_at : nil,
        last_sent_to: copy_cursor ? route.last_sent_to : nil,
        custom_attributes: {}
      ).tap do |operation_route|
        next unless with_stops

        route.stops.each do |stop|
          next if stop.active == false

          build_stop(operation_route, stop, units_by_id, copy_cursor: copy_cursor)
        end
      end
    end

    def build_stop(operation_route, stop, units_by_id, copy_cursor:)
      kind = Snapshots.kind_for(stop)
      visit = stop.visit
      destination = visit&.destination
      store = stop.store || stop.store_reload&.store
      OperationStop.create!(
        operation_route: operation_route,
        stop: stop,
        visit: visit,
        destination: destination,
        store: store,
        store_reload: stop.store_reload,
        kind: kind,
        index: stop.index,
        active: stop.active != false,
        locked: stop.locked || false,
        sync_state: 'active',
        destination_snapshot: Snapshots.destination(destination),
        visit_snapshot: kind == 'visit' ? Snapshots.visit(visit, units_by_id) : {},
        store_snapshot: Snapshots.store(store, stop.store_reload),
        stop_snapshot: Snapshots.stop(stop),
        status: copy_cursor ? stop.status : nil,
        eta: copy_cursor ? stop.eta : nil,
        status_updated_at: copy_cursor ? stop.status_updated_at : nil,
        custom_attributes: stop.custom_attributes || {}
      )
    end

    def leg(route_data, fallback_eta, date)
      [route_data&.status, Snapshots.timestamp_on(date, route_data&.eta || fallback_eta)]
    end

    def chosen_date
      return Date.iso8601(@date.to_s) if @date.present?

      Date.current + @planning.customer.operation_date_offset_default
    rescue ArgumentError, TypeError
      Date.current + @planning.customer.operation_date_offset_default
    end

    # (customer, lower(ref), date) is unique when ref is present.
    def unique_ref(date)
      base = @planning.ref
      return if base.blank?
      return base unless Operation.where(customer_id: @planning.customer_id, date: date)
                                  .where('lower(ref) = ?', base.downcase)
                                  .exists?

      "#{base}~#{SecureRandom.hex(3)}"
    end

    def routes_for(planning)
      planning.routes.includes(:vehicle_usage, :route_geojson, :route_data, :start_route_data, :stop_route_data, stops: [:visit, :store, :store_reload]).to_a
    end
  end
end
