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
class SuiviDeFlotte < DeviceBase
  def definition
    {
      device: 'suivi_de_flotte',
      label: 'SuiviDeFlotte',
      label_small: 'SuiviDeFlotte',
      route_operations: [],
      has_sync: false,
      help: false,
      forms: {
        settings: {
          username: :text,
          password: :password
        },
        vehicle: {
          suivi_de_flotte_id: :select
        },
      }
    }
  end

  def check_auth(credentials)
    response = get(savon_client, nil, :login, {username: credentials[:username], passkey: credentials[:password]}, {})

    response[:login_response][:session_id]
  end

  def list_devices(credentials)
    session_id = check_auth credentials
    response = get(savon_client, nil, :fleet_devices_list, {session_id: session_id}, {})

    response[:fleet_devices_list_response][:device_list][:item].map{ |item|
      {
        id: item[:id_sdf],
        text: [item[:name], item[:reg_plate] && item[:reg_plate].is_a?(String) ? item[:reg_plate] : nil].compact.join(' / '),
      }
    }
  end

  def vehicle_pos(credentials, refs)
    session_id = check_auth credentials
    response = get(savon_client, nil, :fleet_devices_info, {session_id: session_id}, {})

    response[:fleet_devices_info_response][:device_details_list][:item].map{ |item|
      {
        suivi_de_flotte_vehicle_id: item[:id_sdf],
        lat: item[:address][:address][:coord][:lat],
        lng: item[:address][:address][:coord][:lon],
        time: item[:address][:dt],
        speed: 0,
        direction: item[:angle]
      }
    }
  end

  private

  def savon_client
    client ||= Savon.client({
      wsdl: api_url + '?wsdl',
      endpoint: api_url, # Need it to use ssl if api_key is defined with https
      soap_version: 1,
      # log: true,
      # pretty_print_xml: true,
      convert_request_keys_to: :none,
      proxy: ENV['http_proxy']
    }.compact)
  end

  def get(client, no_error_code, operation, message = {}, error_code)
    response = client.call(operation, message: message)

    op_response = (operation.to_s + '_response').to_sym
    op_return = (operation.to_s + '_return').to_sym

    if no_error_code && response.body[op_response] && response.body[op_response][op_return] != no_error_code.to_s
      Rails.logger.info response.body[op_response]
      raise DeviceServiceError.new("Suivi De Flotte operation #{operation} returns error: #{error_code[response.body[op_response][op_return]] || response.body[op_response][op_return]}")
    end
    response.body
  rescue Savon::SOAPFault => error
    Rails.logger.info error
    fault_string = error.to_hash[:fault][:faultstring]
    raise DeviceServiceError.new("Suivi De Flotte: #{fault_string}")
  rescue Savon::HTTPError => error
    if error.http.code == 401
      raise DeviceServiceError.new('Suivi De Flotte: ' + I18n.t('errors.suivi_de_flotte.invalid_account'))
    else
      Rails.logger.info error.http.code
      raise error
    end
  end
end
