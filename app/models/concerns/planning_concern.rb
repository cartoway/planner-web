module PlanningConcern
  extend ActiveSupport::Concern

  def vehicles_usages_map(planning)
    Route.includes_vehicle_usages.scoping do
      planning.routes.map{ |route| route.vehicle_usage if route.vehicle_usage.try(&:active) }.compact.each_with_object({}) do |vehicle_usage, hash|
        router_name =
          vehicle_usage.vehicle.default_router.name_locale[I18n.locale.to_s] ||
          vehicle_usage.vehicle.default_router.name_locale[I18n.default_locale.to_s] ||
          vehicle_usage.vehicle.default_router.name
        hash[vehicle_usage.vehicle_id] =
          vehicle_usage
          .vehicle
          .slice(:name, :color, :capacities, :default_capacities)
          .merge(
            vehicle_usage_id: vehicle_usage.id,
            vehicle_id: vehicle_usage.vehicle_id,
            router_dimension: vehicle_usage.vehicle.default_router_dimension,
            work_or_window_time: vehicle_usage.work_or_window_time,
            vehicle_quantities: vehicle_usage.quantities(planning),
            router_name: router_name
          )
      end
    end
  end
end
