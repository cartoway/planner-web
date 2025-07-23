# Copyright © Mapotempo, 2017
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class Trimble < DeviceBase
  def definition
    {
      device: 'trimble',
      label: 'Trimble',
      label_small: 'Trimble',
      route_operations: [:send],
      has_sync: false,
      help: false,
      forms: {
        settings: {
          customer: :text,
          username: :text,
          password: :password
        },
        vehicle: {
          trimble_ref: :text
        },
      }
    }
  end

  def check_auth(credentials)
    client_customer ||= Savon.client({
      basic_auth: [credentials[:username] || '', credentials[:password] || ''],
      wsdl: api_url + '/Customer?wsdl',
      soap_version: 1,
      # log: true,
      # pretty_print_xml: true,
      convert_request_keys_to: :none,
      proxy: ENV['http_proxy']
    }.compact)

    response = get(client_customer, nil, :get_customer_info, {}, {})
  end

  def send_route(customer, route, _options = {})
    credentials = customer.devices[:trimble]
    client_planning ||= Savon.client({
      basic_auth: [credentials[:username] || '', credentials[:password] || ''],
      wsdl: api_url + '/Planning?wsdl',
      soap_version: 1,
      # log: true,
      # pretty_print_xml: true,
      convert_request_keys_to: :none,
      proxy: ENV['http_proxy']
    }.compact)

    tasks = []
    position = route.vehicle_usage.default_store_start
    task_start = (route.vehicle_usage.default_store_start.try(:position?)) ? [[
        route.vehicle_usage.default_store_start.lat,
        route.vehicle_usage.default_store_start.lng,
        '',
        route.vehicle_usage.default_store_start.name
      ]] : []
    task_stop = (route.vehicle_usage.default_store_stop.try(:position?)) ? [[
        route.vehicle_usage.default_store_stop.lat,
        route.vehicle_usage.default_store_stop.lng,
        '',
        route.vehicle_usage.default_store_stop.name
      ]] : []
    tasks = route.stops.select(&:active).collect{ |stop|
      position = stop if stop.position?
      if position.nil? || position.lat.nil? || position.lng.nil?
        next
      end
      [
        position.lat,
        position.lng,
        stop.is_a?(StopVisit) ? (route.planning.customer.enable_orders ? (stop.order ? stop.order.products.collect(&:code).join(',') : '') : route.planning.customer.deliverable_units.map{ |du| stop.visit.default_quantities[du.id] && "x#{stop.visit.default_quantities[du.id]}#{du.label}" }.compact.join(' ')) : nil,
        stop.name,
        stop.comment,
        stop.phone_number
      ]
    }
    tasks = (task_start + tasks.compact + task_stop).each_with_index.map{ |v, k|
      description = v[2..-1].compact.join(' ').strip
      {
        id: "r#{route.id}_#{k}",
        name: v[3],
        description: description,
        contact: {
          phone: v[5],
          coordinate: {latitude: v[0], longitude: v[1]}
        }.compact,
        activity: {
          id: "r#{route.id}_#{k}_0",
          # MAPO_1 = Collecte / Chargement
          # MAPO_2 = Déchargement
          type: 'MAPO_2'
        }
      }
    }

    params = {
      customer: credentials[:customer],
      tripData: {
        id: "r#{route.id}",
        name: route.ref || route.vehicle_usage.vehicle.name,
        description: '',
        task: tasks
      }
    }

    # 1. :create_trips
    response = get(client_planning, nil, :create_trips, params, {})

    # 2. :assign_trips
    response = get(client_planning, nil, :assign_trips, {customer: credentials[:customer], terminal: route.vehicle_usage.vehicle.devices[:trimble_ref], tripIds: ["r#{route.id}"]}, {})
  end

  private

  def get(client, no_error_code, operation, message = {}, error_code)
    response = client.call(operation, message: message)

    op_response = (operation.to_s + '_response').to_sym
    op_return = (operation.to_s + '_return').to_sym
    if !response.body.key?(op_response)
      Rails.logger.info response.body[op_response]
      raise DeviceServiceError.new("Trimble operation #{operation} returns error: #{error_code[response.body[op_response][op_return]] || response.body[op_response][op_return]}")
    end
    response.body
  rescue Savon::SOAPFault => error
    Rails.logger.info error
    fault_code = error.to_hash[:fault][:faultcode]
    fault_string = error.to_hash[:fault][:faultstring]
    raise DeviceServiceError.new("Trimble: #{fault_code} #{fault_string}")
  rescue Savon::HTTPError => error
    if error.http.code == 401
      raise DeviceServiceError.new('Trimble: ' + I18n.t('errors.trimble.invalid_account'))
    else
      Rails.logger.info error.http.code
      raise error
    end
  end
end
