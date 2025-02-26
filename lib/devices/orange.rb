# Copyright © Mapotempo, 2016
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
require 'builder' # XML
require 'addressable'

class Orange < DeviceBase
  def definition
    {
      device: 'orange',
      label: 'Orange Fleet Performance',
      label_small: 'Orange',
      route_operations: [:send, :clear],
      has_sync: true,
      help: true,
      forms: {
        settings: {
          user: :text,
          password: :password
        },
        vehicle: {
          orange_id: :select,
        },
      }
    }
  end

  def check_auth(params)
    send_request list_operations(nil, { auth: params.slice(:user, :password) })
  end

  def list_devices(customer, params = {})
    # ===============
    #     Unused
    # ===============

    # options = {}
    # options.merge!(auth: params.slice(:user, :password)) if !params.blank?
    # response = send_request get_vehicles(customer, options)
    # if response.code.to_i == 200
    #   vehicle_infos = []
    #   Nokogiri::XML(response.body).xpath('//vehicle').each_with_object({}) do |item, hash|
    #     item.children.select(&:element?).map{ |node| hash[node.name] = node.inner_html }
    #     vehicle_infos << hash
    #   end
    #   vehicle_infos.map do |item|
    #     { id: item['esht'], text: '%s - %s' % [item['vdes'], item['vreg']] }
    #   end
    # else
    #   raise DeviceServiceError.new('Orange: %s' % [I18n.t('errors.orange.list')])
    # end
    []
  end

  def send_route(customer, route, _options = {})
    send_request send_xml_file(customer, route)
  end

  def clear_route(customer, route)
    # Not supported by Garmin 590 -- Garmin Dezl and Nuvi only
    send_request send_xml_file(customer, route, delete: true)
  end

  def vehicle_pos(customer)
    response = send_request(get_positions(customer))
    if response.code.to_i == 200
      vehicle_infos = []
      Nokogiri::XML(response.body).xpath('//position').each_with_object({}) do |item, hash|
        item.children.select(&:element?).map{ |node| hash[node.name] = node.inner_html }
        vehicle_infos << { orange_vehicle_id: hash['esht'], lat: hash['lat'], lng: hash['lon'], speed: hash['speed'], time: hash['hd'] + '+00:00', device_name: hash['vdes'] }
      end
      return vehicle_infos
    else
      raise DeviceServiceError.new('Orange: %s' % [I18n.t('errors.orange.vehicle_pos')])
    end
  end

  private

  def send_request(response)
    if response.code.to_i == 200
      return response
    elsif response.code.to_i == 401
      raise DeviceServiceError.new('Orange: %s' % [I18n.t('errors.orange.unauthorized')])
    else
      Rails.logger.info 'OrangeService: %s %s' % [response.code, response.body]
    end
  end

  def net_request(customer, options)
    # Auth
    if options[:auth]
      user, password = options[:auth][:user], options[:auth][:password]
    else
      user, password = customer.devices[:orange][:user], customer.devices[:orange][:password]
    end

    # HTTP Request w/ SSL
    uri = URI.parse api_url
    http = Net::HTTP.new uri.host, uri.port
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    # GET Data
    request = Net::HTTP::Get.new options[:path]
    request.basic_auth user, password
    request.set_form_data options[:params]
    http.request request
  end

  def get_positions(customer)
    net_request customer, { path: '/webservices/getpositions.php', params: { ext: 'xml' } }
  end

  def get_vehicles(customer, options)
    net_request customer, options.merge(path: '/webservices/getvehicles.php', params: { ext: 'xml' })
  end

  def list_operations(customer, options)
    net_request customer, options.merge(path: '/pnd/index.php', params: { ext: 'xml', ref: '', vehid: '', typ: 'mis', eqpid: '', dtdeb: Time.zone.now.beginning_of_day, dtfin: Time.zone.now.end_of_day })
  end

  def send_xml_file(customer, route, options = {})
    f = Tempfile.new Time.zone.now.to_i.to_s
    f.write to_xml(route, options)
    f.rewind
    response = RestClient::Request.execute(method: :post, user: customer.devices[:orange][:user], password: customer.devices[:orange][:password], url: api_url + '/pnd/index.php', payload: { multipart: true, file: f }) { |resp, req, res|
      case resp.code
        when 301, 302, 307
          resp.follow_redirection
        else
          resp.return!
      end
    }
    f.unlink
    response
    rescue RestClient::RequestTimeout => e
      raise DeviceServiceError.new('orange: %s' % [ I18n.t('errors.orange.timeout') ])
  end

  def to_xml(route, options = {})
    xml = ::Builder::XmlMarkup.new indent: 2
    xml.instruct!
    xml.tag! :ROOT do
      xml.tag! :version
      xml.tag! :transmit, Time.zone.now.strftime('%d/%m/%Y %H:%M')
      xml.tag! :zone, nil, type: 'dest', ref: route.id, eqpid: route.vehicle_usage.vehicle.devices[:orange_id], drivername: nil, vehid: nil, badge: nil
      xml.tag! :zone, nil, type: 'mission', ref: route.id, lang: nil, title: "Mission #{route.id}", txt: route.planning.name,
        prevmisdeb: p_time(route, route.start).strftime('%d/%m/%Y %H:%M'), prevmisfin: p_time(route, route.end).strftime('%d/%m/%Y %H:%M')
      xml.tag! :zone, nil, type: 'operation' do
        route.stops.select(&:active?).select(&:position?).select(&:time?).sort_by(&:index).each do |stop|
          start_time = stop.time
          end_time = stop.duration ? stop.time + stop.duration.seconds : stop.time
          xml.tag! :operation, nil, options.merge(seq: stop.index, ad1: stop.street, ad2: nil, ad3: nil, ad_zip: stop.postalcode,
            ad_city: stop.city, ad_cntry: stop.country || stop.route.planning.customer.default_country, latitude: stop.lat, longitude: stop.lng, title: stop.name, txt: [stop.street, stop.postalcode, stop.city].join(', '),
            prevopedeb: p_time(route, start_time).strftime('%d/%m/%Y %H:%M'), prevopefin: p_time(route, end_time).strftime('%d/%m/%Y %H:%M'))
        end
      end
    end
  end
end
