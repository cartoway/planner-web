# Copyright © Mapotempo, 2015-2016
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

#RestClient.log = $stdout

class Alyacom < DeviceBase

  TIMEOUT_VALUE ||= 120

  def definition
    {
      device: 'alyacom',
      label: 'Alyacom',
      label_small: 'Alyacom',
      route_operations: [:send],
      has_sync: false,
      help: true,
      forms: {
        settings: {
          association: :text,
          alyacom_api_key: :text # FIXME: parameters are sent at root level in api...
        },
        vehicle: {} # Empty hash to display export alyacom on route
      }
    }
  end

  def check_auth(params)
    rest_client_get [api_url, params[:association], 'users'].join('/'), { apiKey: params[:alyacom_api_key] }
  rescue RestClient::Forbidden, RestClient::InternalServerError, RestClient::ResourceNotFound
    raise DeviceServiceError.new('Alyacom: %s' % [ I18n.t('errors.alyacom.unauthorized') ])
  end

  def send_route(customer, route, _options = {})
    position = route.vehicle_usage.default_store_start
    staff = {
      id: route.vehicle_usage.vehicle.name,
      name: route.vehicle_usage.vehicle.name,
      street: position && position.street,
      postalcode: position && position.postalcode,
      city: position && position.city
    }
    waypoints = route.stops.select(&:active).select{ |stop| stop.is_a?(StopVisit) }.collect{ |stop|
      position = stop if stop.position?
      if position.nil? || position.lat.nil? || position.lng.nil? || stop.time.nil?
        next
      end
      {
        user: {
          id: stop.base_id,
          name: stop.name,
          street: [position.street, stop.detail].compact.join(', ').strip,
          postalcode: position.postalcode,
          city: position.city,
          detail: [
              stop.time_window_start_1 || stop.time_window_end_1 ? (stop.time_window_start_1 ? stop.time_window_start_1_time + number_of_days(stop.time_window_start_1) : '') + (stop.time_window_start_1 && stop.time_window_end_1 ? '-' : '') + (stop.time_window_end_1 ? (stop.time_window_end_1_time + number_of_days(stop.time_window_end_1) || '') : '') : nil,
              stop.time_window_start_2 || stop.time_window_end_2 ? (stop.time_window_start_2 ? stop.time_window_start_2_time + number_of_days(stop.time_window_start_2) : '') + (stop.time_window_start_2 && stop.time_window_end_2 ? '-' : '') + (stop.time_window_end_2 ? (stop.time_window_end_2_time + number_of_days(stop.time_window_end_2) || '') : '') : nil,
            stop.comment,
            stop.ref
          ].compact.join(' ').strip
        },
        planning: {
          id: planning_date(route.planning).strftime('%y%m%d') + '_' + stop.base_id.to_s,
          staff_id: route.vehicle_usage.vehicle.name,
          destination_id: stop.base_id,
          comment: [
            stop.is_a?(StopVisit) ? (customer.enable_orders ? (stop.order ? stop.order.products.collect(&:code).join(',') : '') : customer.deliverable_units.map{ |du| stop.visit.default_quantities[du.id] && "x#{stop.visit.default_quantities[du.id]}#{du.label}" }.compact.join(' ')) : nil
          ].compact.join(' ').strip,
          start: planning_date(route.planning) + stop.time,
          end: planning_date(route.planning) + stop.time + stop.duration
        }
      }
    }.compact
    createJobRoute customer, planning_date(route.planning), staff, waypoints
  end

  private

  def createJobRoute(customer, planning_date, staff, waypoints)
    update_staffs customer, [staff]
    update_users customer, waypoints.collect{ |w| w[:user] }

    res = Hash[get(customer, 'planning', fromDate: planning_date.to_i * 1000, idStaff: staff[:id]).select{ |s| s.key?('idExt') }.map{ |s| [s['idExt'], s] }]

    plannings = waypoints.collect{ |waypoint|
      planning = waypoint[:planning]
      res.delete(planning[:id])

      {
        idExt: planning[:id],
        idStaff: planning[:staff_id],
        idUser: planning[:destination_id],
        comment: planning[:comment] != '' ? planning[:comment] : nil,
        start: planning[:start].strftime('%d/%m/%Y %H:%M'),
        end: planning[:end].strftime('%d/%m/%Y %H:%M')
      }
    }

    plannings += res.select{ |_k, planning|
      Date.parse(planning['start']) == planning_date.to_date
    }.collect{ |_k, planning|
      planning['deleted'] = true
      planning
    }

    rest_client_post [api_url, customer.devices[:alyacom][:association], 'planning'].join('/'), { enc: :json, apiKey: customer.devices[:alyacom][:alyacom_api_key] }, plannings
  end

  def update_staffs(customer, staffs)
    res = Hash[get(customer, 'staff').select{ |s| s.key?('idExt') }.collect{ |s| [s['idExt'], s.slice('idExt', 'lastName', 'firstName', 'address', 'postalCode', 'city')]}]

    missing_or_update = staffs.collect{ |s|
      {
        'idExt' => s[:id],
        'firstName' => '',
        'lastName' => s[:name],
        'address' => s[:street],
        'postalCode' => s[:postalcode],
        'city' => s[:city]
      }
    }.delete_if{ |h| res.key?(h['idExt']) && res[h['idExt']].all?{ |k, v| h[k] == v } }

    if !missing_or_update.empty?
      rest_client_post [api_url, customer.devices[:alyacom][:association], 'staff'].join('/'), { enc: :json, apiKey: customer.devices[:alyacom][:alyacom_api_key] }, missing_or_update
    end
  end

  def update_users(customer, users)
    res = Hash[get(customer, 'users').select{ |s| s.key?('idExt') }.collect{ |s| [s['idExt'], s.slice('idExt', 'lastName', 'firstName', 'address', 'postalCode', 'city', 'accessInfo')]}]

    missing_or_update = users.collect{ |s|
      {
        'idExt' => s[:id],
        'firstName' => '',
        'lastName' => s[:name],
        'address' => s[:street],
        'postalCode' => s[:postalcode],
        'city' => s[:city],
        'accessInfo' => s[:detail],
      }
    }.delete_if{ |h| res.key?(h['idExt']) && res[h['idExt']].all?{ |k, v| h[k] == v } }

    if !missing_or_update.empty?
      rest_client_post [api_url, customer.devices[:alyacom][:association], 'users'].join('/'), { enc: :json, apiKey: customer.devices[:alyacom][:alyacom_api_key] }, missing_or_update
    end
  end

  def get(customer, object, params = {})
    get_raw "#{api_url}/#{customer.devices[:alyacom][:association]}/#{object}", { enc: :json, apiKey: customer.devices[:alyacom][:alyacom_api_key] }.merge(params)
  end

  def get_raw(url, params)
    data = []
    next_ = nil
    begin
      begin
        response = rest_client_get next_ || url, params
      rescue => e
        Rails.logger.info next_ || url
        begin
          # Parse malformed Json, replace key by string, simple quote by double quote
          response = JSON.parse(e.response.tr('\'', '"').gsub(/([\'\"])?([a-zA-Z0-9_]+)([\'\"])?:/, '"\2":'))
        rescue
          Rails.logger.info e
          raise e
        end
        if !response['message'].blank?
          Rails.logger.info response['message']
          raise DeviceServiceError.new('Alyacom: %s' % [ response['message'] ])
        else
          Rails.logger.info e
          raise e
        end
      end
      response = JSON.parse(response)
      if response.key?('data') && !response['data'].empty?
        data += response['data'].select{ |i| !i['deleted'] }
      end

      if response.key?('data') && !response['data'].empty? && !response['data'][-1]['deleted'] # Stop if last page items are deleted
        next_ = response['next']
      else
        next_ = nil
      end
    end while !next_.nil?
    data
  end

  def rest_client_get(url, params)
    RestClient::Request.execute method: :get, url: url, timeout: TIMEOUT_VALUE, headers: { params: params }
  rescue RestClient::RequestTimeout => e
    raise DeviceServiceError.new('Alyacom: %s' % [ I18n.t('errors.alyacom.timeout') ])
  end

  def rest_client_post(url, params, data)
    Rails.logger.info data.inspect
    RestClient::Request.execute(method: :post, url: url, timeout: TIMEOUT_VALUE, headers: { content_type: :json, params: params }, payload: data.to_json) { |response, request, result|
      case response.code
      when 301, 302, 307
        response.follow_redirection
      else
        response.return!
      end
    }
  rescue RestClient::RequestTimeout => e
    raise DeviceServiceError.new('Alyacom: %s' % [ I18n.t('errors.alyacom.timeout') ])
  end
end
