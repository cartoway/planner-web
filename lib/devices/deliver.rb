#RestClient.log = 'stdout'

class Deliver < DeviceBase
  def definition
    {
      device: 'deliver',
      label: 'Cartoway Deliver',
      label_small: 'Deliver',
      route_operations: [:send, :clear],
      has_sync: true,
      has_operations: true,
      help: true,
      forms: {
        settings: {
          driver_move: :boolean,
          demo: :boolean
        },
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
    # Field status lives on Operations when Deliver unlocks has_operations.
    return true if customer.device.operations_enabled?

    route.start_route_data.assign_attributes status: nil, eta: nil
    route.stop_route_data.assign_attributes status: nil, eta: nil
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

  # Planning stop status is no longer the Deliver source of truth; use Operations API.
  def fetch_stops(_customer = nil, _date = nil, _planning = nil)
    []
  end

  def transfer_stops(customer, route, stop_id)
    stop = route.stops.find(stop_id)
    stop.update(route_idstatus: nil, eta: nil)
  end
end
