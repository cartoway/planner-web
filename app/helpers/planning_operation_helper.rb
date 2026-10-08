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

  def planning_summary(planning)
    {
      planning_id: planning.id,
      planning_ref: planning.ref,
      external_callback_name: planning.customer.enable_external_callback && planning.customer.external_callback_name,
      external_callback_url: planning.customer.enable_external_callback && planning.customer.external_callback_url,
      routes: planning.routes.map{ |route|
        {
          route_id: route.id,
          vehicle_usage_id: route.vehicle_usage_id,
          vehicle_id: route.vehicle_usage&.vehicle_id,
          name: [route.ref, route.vehicle_usage&.vehicle&.name || t('plannings.edit.out_of_route')].compact_blank.join(' '),
          color: route.color || route.vehicle_usage&.vehicle&.color || '#707070',
          hidden: route.hidden,
          locked: route.locked,
          data: route.slice(
            :out_of_window, :out_of_capacity, :out_of_drive_time, :out_of_work_time,
            :out_of_max_distance, :out_of_max_reload, :out_of_relation, :out_of_skill,
            :no_path, :unmanageable_capacity
          ).merge(
            size: route.route_data.stops_size,
            size_active: route.route_data.size_active,
            size_store_reloads: route.route_data.size_store_reloads,
            out_of_route: route.vehicle_usage_id.nil?
          ),
        }.delete_if{ |_k, v| v.nil? }
      }
    }
  end

  def attach_open_operations!(route_data, planning, route_id = route_data[:route_id])
    return route_data unless planning.customer.device.operations_enabled?

    operation = planning.open_operation_for_route_today(route_id)
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
