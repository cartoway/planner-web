# frozen_string_literal: true

# Operation-facing planning summaries used by edit/sidebar payloads.
module PlanningOperationHelper
  def plannings_summary(customer)
    {
      external_callback_name: customer.enable_external_callback && customer.external_callback_name,
      external_callback_url: customer.enable_external_callback && customer.external_callback_url,
      plannings: customer.plannings.map{ |planning|
        {
          planning_id: planning.id,
          planning_ref: planning.ref
        }
      }
    }
  end

  # routes: optional subset (partial summary) — avoids Planning refetch + target= hack.
  def planning_summary(planning, routes: nil)
    route_list = routes || planning.routes
    {
      planning_id: planning.id,
      planning_ref: planning.ref,
      external_callback_name: planning.customer.enable_external_callback && planning.customer.external_callback_name,
      external_callback_url: planning.customer.enable_external_callback && planning.customer.external_callback_url,
      routes: route_list.map{ |route|
        vehicle = route.vehicle_usage&.vehicle
        {
          route_id: route.id,
          vehicle_usage_id: route.vehicle_usage_id,
          vehicle_id: vehicle&.id,
          name: [route.ref, vehicle&.name || t('plannings.edit.out_of_route')].compact_blank.join(' '),
          color: route.color || vehicle&.color || '#707070',
          hidden: route.hidden,
          locked: route.locked,
          # Used by the operation-create modal to refresh driver contacts after vehicle switch.
          contact_email: vehicle&.contact_email,
          phone_number: vehicle&.phone_number,
          data: route.slice(
            :out_of_window, :out_of_capacity, :out_of_drive_time, :out_of_work_time,
            :out_of_max_distance, :out_of_max_reload, :out_of_relation, :out_of_skill,
            :no_path, :unmanageable_capacity
          ).merge(
            size: route.stops_size,
            size_active: route.size_active,
            size_store_reloads: route.size_store_reloads.to_i,
            out_of_route: route.vehicle_usage_id.nil?
          ),
        }.delete_if{ |_k, v| v.nil? }
      }
    }
  end

  # Touched-route summary for move / update_stop / active — front merges into its list.
  def planning_partial_summary(planning, route_ids)
    loaded = Route.where(planning_id: planning.id, id: route_ids)
                  .preload(:route_data, :start_route_data, :stop_route_data, vehicle_usage: :vehicle)
                  .ordered_for_planning
                  .to_a
    planning_summary(planning, routes: loaded).merge(partial: true)
  end

  # Active vehicle store center, else customer default (shared by web + api_web edit).
  def planning_map_center(planning)
    usages = planning.vehicle_usage_set&.vehicle_usages || []
    store = usages.select(&:active?).lazy.map(&:default_store_start).find { |s| s&.lat && s.lng }
    default = planning.customer.default_position
    { lat: store&.lat || default[:lat], lng: store&.lng || default[:lng] }
  end

  # open_ops_by_route: optional { route_id => [Operation, ...] } from Planning#open_operations_by_route_id
  # to avoid one query per route on planning show/refresh.
  def attach_open_operations!(route_data, planning, route_id = route_data[:route_id], open_ops_by_route: nil)
    return route_data unless planning.customer.device.operations_enabled?

    operation = if open_ops_by_route
                  (open_ops_by_route[route_id] || []).find { |op| op.date == Date.current }
                else
                  planning.open_operation_for_route_today(route_id)
                end
    route_data[:today_operation] = if operation
      {
        id: operation.id,
        name: operation.name,
        path: operation_path(operation)
      }
    end
    route_data
  end

  # HTML label for planning route checklist (name + stops + error badges).
  def planning_route_checklist_label(route_summary)
    data = (route_summary[:data] || {}).with_indifferent_access
    label = route_summary[:name].to_s
    size = data[:size].to_i
    if size.positive?
      label += if data[:out_of_route]
        " - #{size}"
      else
        active = data[:size_active].nil? ? size : data[:size_active].to_i
        " - #{active}/#{size}"
      end
    end

    parts = [ERB::Util.html_escape(label)]
    size_store_reloads = data[:size_store_reloads].to_i
    if size_store_reloads.positive?
      parts << " <i class=\"fa fa-arrows-rotate fa-fw fa-route-selector\" title=\"#{ERB::Util.html_escape(t('plannings.edit.sub_tour.reloads'))}\"></i> #{size_store_reloads}"
    end

    error_badges = [
      [:out_of_window, 'fa-stopwatch', 'plannings.edit.error.out_of_window_help'],
      [:out_of_capacity, 'fa-dumpster', 'plannings.edit.error.out_of_capacity_help'],
      [:out_of_drive_time, 'fa-power-off', 'plannings.edit.error.out_of_drive_time_help'],
      [:out_of_work_time, 'fa-repeat', 'plannings.edit.error.out_of_work_time_help'],
      [:out_of_max_distance, 'fa-ruler', 'plannings.edit.error.out_of_max_distance_help'],
      [:out_of_max_ride_distance, 'fa-compass-drafting', 'plannings.edit.error.out_of_max_ride_distance_help'],
      [:out_of_max_ride_duration, 'fa-stopwatch-20', 'plannings.edit.error.out_of_max_ride_duration_help'],
      [:out_of_max_reload, 'fa-arrows-rotate', 'plannings.edit.error.out_of_max_reload_help'],
      [:out_of_relation, 'fa-link', 'plannings.edit.error.out_of_relation_help'],
      [:out_of_skill, 'fa-user-check', 'plannings.edit.error.out_of_skill_help'],
      [:no_path, 'fa-road', 'plannings.edit.error.no_path_help'],
      [:unmanageable_capacity, 'fa-times', 'plannings.edit.error.unmanageable_capacity_help']
    ]
    error_badges.each do |key, icon, help_key|
      next unless ActiveModel::Type::Boolean.new.cast(data[key])

      parts << " <span class=\"badge badge-danger\" title=\"#{ERB::Util.html_escape(t(help_key))}\"><i class=\"fa #{icon} fa-fw\"></i></span>"
    end
    parts.join.html_safe
  end
end
