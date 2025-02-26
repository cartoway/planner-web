class DeliverService < DeviceService
  def initialize(params)
    super(params)
    # Increase specificaly the cache duration as the position are set directly
    @cache_object = Planner::Application.config.devices.deliver_cache_object
  end

  def vehicle_pos
    if customer.devices[service_name]
      with_cache [:vehicle_pos, service_name, customer.id] do
        []
      end
    end
  end

  def cache_position(vehicle, data)
    if customer.devices[service_name]
      store_cache(
        [:vehicle_pos, service_name, customer.id],
        :vehicle_id,
        service.set_vehicle_pos(customer, vehicle, data)
      )
    end
  end
end
