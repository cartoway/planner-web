class PlannerService < DeviceService
  def initialize(params)
    super(params)
    # Increase specificaly the cache duration as the position are set directly
    @cache_object = Mapotempo::Application.config.devices.planner_cache_object
  end

  def get_vehicles_pos
    if customer.devices[service_name]
      with_cache [:get_vehicles_pos, service_name, customer.id] do
        []
      end
    end
  end

  def cache_position(vehicle, data)
    if customer.devices[service_name]
      store_cache(
        [:get_vehicles_pos, service_name, customer.id],
        :vehicle_id,
        service.set_vehicle_pos(customer, vehicle, data)
      )
    end
  end
end
