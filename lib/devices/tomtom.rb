# Copyright © Mapotempo, 2014-2016
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
class Tomtom < DeviceBase
  attr_reader :client_objects, :client_address, :client_orders

  class TomTomServiceBusyError < StandardError; end

  def definition
    {
      device: 'tomtom',
      label: 'TomTom WEBFLEET',
      label_small: 'TomTom',
      route_operations: [{send: :orders}, {send: :waypoints}, :clear],
      has_sync: true,
      help: true,
      forms: {
        settings: {
          account: :text,
          user: :text,
          password: :password
        },
        vehicle: {
          tomtom_id: :select
        },
      }
    }
  end

  def savon_client_objects
    @client_objects ||= Savon.client({wsdl: api_url + '/objectsAndPeopleReportingService?wsdl', multipart: true, soap_version: 2, open_timeout: 60, read_timeout: 60, proxy: ENV['http_proxy']}.compact) do
      #log true
      #pretty_print_xml true
      convert_request_keys_to :none
    end
  end

  def savon_client_address
    @client_address ||= Savon.client({wsdl: api_url + '/addressService?wsdl', multipart: true, soap_version: 2, open_timeout: 60, read_timeout: 60, proxy: ENV['http_proxy']}.compact) do
      #log true
      #pretty_print_xml true
      convert_request_keys_to :none
    end
  end

  def savon_client_orders
    @client_orders ||= Savon.client({wsdl: api_url + '/ordersService?wsdl', multipart: true, soap_version: 2, open_timeout: 60, read_timeout: 60, proxy: ENV['http_proxy']}.compact) do
      #log true
      #pretty_print_xml true
      convert_request_keys_to :none
    end
  end

  @@vehicle_colors = {
    'white' => '#ffffff',
    'grey' => '#808080',
    'black' => '#000000',
    'ivory' => '#FFFFF0',
    'red' => '#FF0000',
    'orange' => '#FFA500',
    'yellow' => '#FFFF00',
    'green' => '#008000',
    'blue' => '#0000FF'
  }

  @@order_status = {
    'NotYetSent' => nil,
    'Sent' => 'Planned',
    'Received' => 'Planned',
    'Read' => 'Planned',
    'Accepted' => 'Planned',
    'ServiceOrderStarted' => 'Started',
    'ArrivedAtDestination' => 'Started',
    'WorkStarted' => 'Started',
    'WorkFinished' => 'Finished',
    'DepartedFromDestination' => 'Finished',
    'PickupOrderStarted' => 'Started',
    'ArrivedAtPickUpLocation' => 'Started',
    'PickUpStarted' => 'Started',
    'PickUpFinished' => 'Finished',
    'DepartedFromPickUpLocation' => 'Finished',
    'DeliveryOrderStarted' => 'Started',
    'ArrivedAtDeliveryLocation' => 'Started',
    'DeliveryStarted' => 'Started',
    'DeliveryFinished' => 'Finished',
    'DepartedFromDeliveryLocation' => 'Finished',
    'Resumed' => 'Started',
    'Suspended' => nil,
    'Cancelled' => 'Rejected',
    'Rejected' => 'Rejected',
    'Finished' => 'Finished',
  }

  def check_auth(params)
    list_devices nil, { auth: params.slice(:account, :user, :password) }
  end

  def list_devices(customer, params = {})
    objects = get customer, savon_client_objects, :show_object_report, {}, params
    objects = [objects] if objects.is_a?(Hash)
    objects.select{ |object| !object[:deleted] }.collect do |object|
      {
        id: object[:@object_uid],
        text: [object[:@object_no], object[:object_name]].join(" / ")
      }
    end
  end

  def vehicle_pos(customer)
    objects = get customer, savon_client_objects, :show_object_report, {}, {}, true
    objects = [objects] if objects.is_a?(Hash)
    objects.select{ |object| !object[:deleted] }.collect do |object|
      {
        tomtom_vehicle_id: object[:@object_uid],
        device_name: object[:object_name],
        lat: object[:position] ? object[:position][:latitude].to_i / 1e6 : nil,
        lng: object[:position] ? object[:position][:longitude].to_i / 1e6 : nil,
        time: object[:pos_time],
        speed: object[:speed],
        direction: object[:course]
      }
    end if objects
  end

  def list_vehicles(customer, params = {})
    options = {}
    options.merge!(auth: params.slice(:account, :user, :password)) if !params.blank?
    objects = get customer, savon_client_objects, :show_vehicle_report, {}, options
    objects = [objects] if objects.is_a?(Hash)
    objects.select{ |object| !object[:deleted] }.collect do |object|
      hash = {
        objectUid: object[:@object_uid],
        objectName: object[:object_name],
        fuelType: object[:vehicle_fuel_type],
        description: object[:description]
      }
      if object[:vehicle_color] && @@vehicle_colors.key?(object[:vehicle_color].downcase)
        hash[:color] = @@vehicle_colors[object[:vehicle_color].downcase]
      else
        hash[:color] = '#000000'
      end
      hash
    end
  end

  def list_addresses(customer)
    addresss = get customer, savon_client_address, :show_address_report
    addresss = [addresss] if addresss.is_a?(Hash)
    addresss.select{ |object| !object[:deleted] }.collect do |address|
      {
        ref: address[:@address_uid] && 'tomtom:' + address[:@address_uid],
        name: address[:name1] || address[:name2] || address[:name3],
        comment: [address[:info], address[:contact][:contactName]].compact.join(', '),
        street: address[:location][:street],
        postalcode: address[:location][:postcode],
        city: address[:location][:city],
        country: address[:location][:country],
        lat: (address[:location][:geo_position] && address[:location][:geo_position][:latitude] && address[:location][:geo_position][:latitude].to_i / 1e6),
        lng: (address[:location][:geo_position] && address[:location][:geo_position][:longitude] && address[:location][:geo_position][:longitude].to_i / 1e6),
        detail: address[:location][:description],
        phone_number: address[:contact][:phoneBusiness] || address[:contact][:phoneMobile] || address[:contact][:phonePersonal],
      }
    end
  end

  def send_route(customer, route, options = {})
    case options[:type].to_sym
    when :orders
      position = route.vehicle_usage.default_store_start
      if position && !position.lat.nil? && !position.lng.nil?
        send_destination_order customer, route, position, -2, route.vehicle_usage.default_store_start && route.vehicle_usage.default_store_start.name || "#{position.lat} #{position.lng}", route.start
      end
      route.stops.select(&:active).each{ |stop|
        position = stop if stop.position?
        if (position && !position.lat.nil? && !position.lng.nil?) || position.is_a?(StopRest)
          description = [
            '',
            stop.name,
            stop.is_a?(StopVisit) ? (customer.enable_orders ? (stop.order ? stop.order.products.collect(&:code).join(',') : '') : customer.deliverable_units.map{ |du| stop.visit.default_quantities[du.id] && "x#{stop.visit.default_quantities[du.id]}#{du.label}" }.compact.join(' ')) : nil,
            stop.is_a?(StopVisit) ? (stop.visit.duration ? '(' + stop.visit.duration_time_with_seconds + ')' : nil) : route.vehicle_usage.default_rest_duration_time_with_seconds,
            stop.time_window_start_1 || stop.time_window_end_1 ? (stop.time_window_start_1 ? stop.time_window_start_1_time + number_of_days(stop.time_window_start_1) : '') + (stop.time_window_start_1 && stop.time_window_end_1 ? '-' : '') + (stop.time_window_end_1 ? (stop.time_window_end_1_time + number_of_days(stop.time_window_end_1) || '') : '') : nil,
            stop.time_window_start_2 || stop.time_window_end_2 ? (stop.time_window_start_2 ? stop.time_window_start_2_time + number_of_days(stop.time_window_start_2) : '') + (stop.time_window_start_2 && stop.time_window_end_2 ? '-' : '') + (stop.time_window_end_2 ? (stop.time_window_end_2_time + number_of_days(stop.time_window_end_2) || '') : '') : nil,
            stop.detail,
            stop.comment,
            stop.phone_number,
          ].compact.join(' ').strip
          send_destination_order customer, route, position, (stop.is_a?(StopVisit) ? "v#{stop.visit_id}" : "r#{stop.id}"), description, stop.time
        end
      }
      position = route.vehicle_usage.default_store_stop
      if position && !position.lat.nil? && !position.lng.nil?
        send_destination_order customer, route, position, -1, route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.name || "#{position.lat} #{position.lng}", route.end
      end

    when :waypoints
      position = route.vehicle_usage.default_store_start
      waypoint_start = (route.vehicle_usage.default_store_start && route.vehicle_usage.default_store_start.position?) ? [[
          route.vehicle_usage.default_store_start.lat,
          route.vehicle_usage.default_store_start.lng,
          '',
          route.vehicle_usage.default_store_start.name
        ]] : []
      waypoint_stop = (route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.position?) ? [[
          route.vehicle_usage.default_store_stop.lat,
          route.vehicle_usage.default_store_stop.lng,
          '',
          route.vehicle_usage.default_store_stop.name
        ]] : []
      waypoints = route.stops.select(&:active).collect{ |stop|
        position = stop if stop.position?
        if position.nil? || position.lat.nil? || position.lng.nil?
          next
        end
        [
          position.lat,
          position.lng,
          stop.is_a?(StopVisit) ? (customer.enable_orders ? (stop.order ? stop.order.products.collect(&:code).join(',') : '') : customer.deliverable_units.map{ |du| stop.visit.default_quantities[du.id] && "x#{stop.visit.default_quantities[du.id]}#{du.label}" }.compact.join(' ')) : nil,
          stop.name,
          stop.comment,
          stop.phone_number
        ]
      }
      waypoints = (waypoint_start + waypoints.compact + waypoint_stop).map{ |l|
        description = l[2..-1].compact.join(' ').strip
        {lat: l[0], lng: l[1], description: description}
      }
      position = route.vehicle_usage.default_store_stop if route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.position?
      description = route.ref || (waypoints[-1] && waypoints[-1][:description]) || "#{waypoints[-1][:lat]} #{waypoints[-1][:lng]}"
      send_destination_order customer, route, position, route.vehicle_usage.id, description, route.start, waypoints
    end
  end

  def clear_route(customer, route)
    get customer, savon_client_orders, :clear_orders, {
      deviceToClear: {
        markDeleted: 'true',
      },
      attributes!: {
        deviceToClear: {
          objectUid: route.vehicle_usage.vehicle.devices[:tomtom_id],
        }
      }
    }
  end

  def fetch_stops(customer, date, _planning)
    orders = get customer, savon_client_orders, :show_order_report, {
      queryFilter: {
        dateRange: {
          from: date.iso8601,
          to: (date + 2.day).iso8601 # FIXME remove hard limit of 2 days
        },
        attributes!: {
          dateRange: {
            rangePattern: 'UD'
          }
        }
      }
    }, {}, false, true
    orders = [orders] if orders.is_a?(Hash)

    orders && orders.collect{ |order| {
      order_id: decode_uid(order[:order_id]),
      status: @@order_status[order[:order_state][:@state_code]] || order[:order_state][:@state_code],
      eta: order[:estimated_arrival_time]
    } } || []
  end

  private

  def get(customer, client, operation, message={}, options={}, ignore_busy = false, ignore_addresses_empty_result = false)
    if options[:auth]
      account, username, password = options[:auth][:account], options[:auth][:user], options[:auth][:password]
    else
      account, username, password = customer.devices[:tomtom][:account], customer.devices[:tomtom][:user], customer.devices[:tomtom][:password]
    end

    message[:order!] = [:aParm, :gParm] + (message[:order!] || (message.keys - [:attributes!]))
    message[:aParm] = {
      apiKey: api_key,
      accountName: account,
      userName: username,
      password: password,
    }
    message[:gParm] = {}

    with_retries do
      response = client.call(operation, message: message)
      response_body = response.body.first[1][:return]
      status_code = response_body[:status_code].to_i
      raise TomTomServiceBusyError.new if status_code == 8015 && !ignore_busy
      if status_code == 0 || (ignore_busy && status_code == 8015) || (ignore_addresses_empty_result && status_code == 9198)
        return response_body[:results][:result_item] if response_body[:results]
      else
        raise DeviceServiceError.new("TomTom: #{parse_error_msg(status_code) || response_body[:status_message]}")
      end
    end

  rescue SocketError, Net::OpenTimeout => error
    Rails.logger.info error
    raise DeviceServiceError.new("TomTom: #{I18n.t('errors.tomtom.unreachable')}")
  rescue Savon::SOAPFault => error
    Rails.logger.info error
    fault_code = error.to_hash[:fault][:faultcode]
    raise DeviceServiceError.new("TomTom: #{fault_code}")
  rescue Savon::HTTPError => error
    Rails.logger.info error.http.code
    raise error
  end

  def with_retries(max_tries=5)
    i = 0
    loop do
      if i == max_tries
        raise DeviceServiceError.new("TomTom: #{I18n.t('errors.tomtom.service_failed')}")
      end
      begin
        yield
        break
      rescue TomTomServiceBusyError
        i += 1
        sleep 5 * i
      end
    end
  end

  def parse_error_msg(status_code)
    # https://uk.support.business.tomtom.com/ci/fattach/get/1331065/1450429305/redirect/1/session/L2F2LzEvdGltZS8xNDUyNjk2OTAzL3NpZC9yVVVpQ3FHbQ==/filename/WEBFLEET.connect-en-1.26.0.pdf
    case status_code
    when 10, 20, 40
      I18n.t 'errors.tomtom.last_action_failed'
    when 45
      I18n.t 'errors.tomtom.access_denied'
    when 1101
      I18n.t 'errors.tomtom.invalid_account'
    when 2515
      I18n.t 'errors.tomtom.duplicate_order'
    when 2605
      I18n.t 'errors.tomtom.gps_unreachable'
    when 2615
      I18n.t 'errors.tomtom.unsupported_export_type'
    when 8011
      I18n.t 'errors.tomtom.request_quota_reached'
    when 8014
      I18n.t 'errors.tomtom.external_requests_not_allowed'
    when 8015
      I18n.t 'errors.tomtom.busy_processing'
    when 9000
      I18n.t 'errors.tomtom.could_not_process_last_request'
    when 9126
      I18n.t 'errors.tomtom.hostname_not_allowed'
    when 9198
      I18n.t 'errors.tomtom.addresses_empty_result'
    end
  end

  def send_destination_order(customer, route, position, order_id, description, time, waypoints = nil)
    objectuid = route.vehicle_usage.vehicle.devices[:tomtom_id]
    params = {
      dstOrderToSend: {
        orderText: strip_sql(description).strip.mb_chars.limit(500).to_s,
        explicitDestination: {
          street: (strip_sql(position.street.strip.mb_chars.limit(50).to_s) if position.street),
          postcode: (strip_sql(position.postalcode.strip.mb_chars.limit(10).to_s) if position.postalcode),
          city: (strip_sql(position.city.strip.mb_chars.limit(50).to_s) if position.city),
          geoPosition: '',
          attributes!: {
            geoPosition: {
              latitude: (position.lat * 1e6).round.to_s,
              longitude: (position.lng * 1e6).round.to_s,
            }
          },
          order!: [:street, :postcode, :city, :geoPosition]
        }
      },
      object: '',
      attributes!: {
        object: {
          objectUid: objectuid,
        },
        dstOrderToSend: {
          orderNo: encode_uid(description, order_id),
          orderType: 'DELIVERY_ORDER',
          scheduledCompletionDateAndTime: time
        }
      }
    }

    (params[:attributes!][:dstOrderToSend][:scheduledCompletionDateAndTime] = p_time(route, time).iso8601) if time

    if waypoints
      params[:advancedSendDestinationOrderParm] = {waypoints: {
        waypoint: waypoints.collect{ |waypoint|
          {
            latitude: (waypoint[:lat] * 1e6).round.to_s,
            longitude: (waypoint[:lng] * 1e6).round.to_s,
            description: strip_sql(waypoint[:description]).tr(',', ' ').strip.mb_chars.limit(20).to_s
          }
        }
      }}
    end
    get customer, savon_client_orders, :send_destination_order, params
  end

  def strip_sql(string)
    # Strip Quotes, forbidden by service in some cases (before Union or Select)
    string.tr('\'', "\u2019").tr("\r", ' ').tr("\n", ' ').gsub(/\s+/, ' ')
  end
end
