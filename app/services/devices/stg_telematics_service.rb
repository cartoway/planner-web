class StgTelematicsService < DeviceService

  def initialize(params)
    super(params)
    # Increase specificaly the cache duration as the api delays are longer
    @cache_object = Planner::Application.config.devices.stg_telematics_cache_object
  end

  def get_vehicles_pos
    if customer.devices[service_name] && customer.devices[:stg_telematics][:username]
      with_cache [:get_vehicles_pos, service_name, customer.id, customer.devices[:stg_telematics][:username]] do
        service.get_vehicles_pos customer
      end
    end
  end

  def list_devices
    if customer.devices[service_name] && customer.devices[:stg_telematics][:username]
      with_cache [:list_devices, service_name, customer.id, customer.devices[:stg_telematics][:username]] do
        service.list_devices customer
      end
    else
      []
    end
  end
end
