#RestClient.log = 'stdout'

class Deliver < DeviceBase
  def definition
    {
      device: 'deliver',
      label: 'Cartoway Deliver',
      label_small: 'Deliver',
      route_operations: [:send, :clear],
      has_sync: true,
      help: true,
      forms: {
        vehicle: {}
      }
    }
  end

  def send_route(customer, route, _options = {})
    email = route.vehicle_usage.vehicle.contact_email
    return if email.nil?

    if Planner::Application.config.delayed_job_use
      RouteMailer.delay.send_driver_route(customer, I18n.locale, email, route)
    else
      RouteMailer.send_driver_route(customer, I18n.locale, email, route).deliver_now
    end
  end

  def clear_route(customer, route)
    route.stops.each { |s| s.assign_attributes status: nil, eta: nil }
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
end
