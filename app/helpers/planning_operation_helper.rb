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
end
