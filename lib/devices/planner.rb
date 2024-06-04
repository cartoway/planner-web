class DeviceExpiredTokenError < StandardError
end

#RestClient.log = 'stdout'

class Planner < DeviceBase
  def definition
    {
      device: 'planner',
      label: 'Planner Cartoway',
      label_small: 'Planner',
      route_operations: [:send],
      has_sync: true,
      help: true,
      forms: {
        vehicle: {}
      }
    }
  end

  def send_route(customer, route, _options = {})
    email = route.vehicle_usage.vehicle.contact_email
    if Mapotempo::Application.config.delayed_job_use
      RouteMailer.delay.send_driver_route(customer, I18n.locale, email, route)
    else
      RouteMailer.send_driver_route(customer, I18n.locale, email, route).deliver_now
    end
  end

  def clear_route(customer, route)
    true
  end

  def set_vehicle_pos(customer, vehicle, data)
    {
      vehicle_id: vehicle.id,
      device_name: vehicle.name,
      lat: data['latitude'],
      lng: data['longitude'],
      time: DateTime.now,
      speed: data['speed'] && (data['speed'].to_f * 3.6).round,
      direction: data['heading']
    }
  end

  def fetch_stops
    planning.routes.select(&:vehicle_usage_id).flat_map{ |r|
      r.stops.select(&:status).map { |s|
        {
          order_id: (s.is_a?(StopVisit) ? "v#{s.visit_id}" : "r#{s.id}"),
          status: s.status,
          eta: s.eta
        }
      }
    }.compact
  end

  def get_vehicles_pos(customer)
    planning = customer.plannings.sort_by(&:updated_at).last
    customer.vehicles.map{ |v|
      route = planning.routes.find{ |r| r.vehicle_usage && r.vehicle_usage.vehicle_id == v.id }
      stops = route ? route.stops.select{ |s| s.position? } : []
      {
        vehicle_id: v.id,
        device_name: v.name,
        lat: stops.size > 0 ? stops.map{ |s| s.position.lat }.sum(0) / stops.size + Random.new.rand(10) * 0.01 : customer.stores.first.lat,
        lng: stops.size > 0 ? stops.map{ |s| s.position.lng }.sum(0) / stops.size + Random.new.rand(10) * 0.01 : customer.stores.first.lng,
        time: Time.now,
        speed: stops.size > 0 ? Random.new.rand(90) : 0,
        direction: stops.size > 0 ? Random.new.rand(360) : 0
      }
    }
  end
end
