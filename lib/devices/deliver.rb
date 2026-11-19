#RestClient.log = 'stdout'

class Deliver < DeviceBase
  def definition
    {
      device: 'deliver',
      label: 'Cartoway Deliver',
      label_small: 'Deliver',
      route_operations: [:send],
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

  # Expects an OperationRoute (Deliver email/SMS go through operations, not planning Route).
  def send_route(customer, operation_route, _options = {})
    email = operation_route.driver_email
    return if email.blank?

    if Planner::Application.config.delayed_job_use
      RouteMailer.delay.send_operation_route(customer, I18n.locale, email, operation_route)
    else
      RouteMailer.send_operation_route(customer, I18n.locale, email, operation_route).deliver_now
    end
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

  # Planning stop status/eta is no longer the Deliver source of truth; use Operations API.
  def fetch_stops(_customer = nil, _date = nil, _planning = nil)
    []
  end

  def transfer_stops(_customer, _route, _stop_id)
    # no-op: execution ETA lives on operation_stops
  end
end
