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
require 'addressable/uri'
require_relative './fleet_modules/fleet_builder.rb'

#RestClient.log = $stdout

class Fleet < DeviceBase
  include FleetBuilder

  TIMEOUT_VALUE ||= 600 # Only for post and delete

  # TODO: use empty roles and fleet API should define default roles...
  USER_DEFAULT_ROLES = [
    'route.updating',
    # 'mission.creating',
    'mission.updating',
    # 'mission.deleting',
    'mission_action.creating',
    'mission_action.updating',
    'user_settings.creating',
    'user_settings.updating',
    'user_current_location.creating',
    'user_current_location.updating',
    'user_track.creating',
    'user_track.updating'
  ]

  def definition
    {
      device: 'fleet',
      label: 'Cartoway Field',
      label_small: 'Mapo. Live',
      route_operations: [:send, :fetch_routes],
      has_sync: true,
      has_create_device: true,
      has_create_user: true,
      help: true,
      forms: {
        settings: {
          user: :text,
          api_key: :password
        },
        vehicle: {
          fleet_user: :select
        }
      }
    }
  end

  # Available status: Planned / Started / Finished / Rejected
  @@order_status = {
    'mission_to_do' => 'Planned',
    'departure_to_do' => 'Planned',
    'rest_to_do' => 'Planned',
    'arrival_to_do' => 'Planned',
    'mission_in_progress' => 'Started', # legacy
    'departure_loading' => 'Started',
    'departure_service' => 'Started',
    'rest_resting' => 'Started', # legacy
    'rest_in_progress' => 'Started',
    'arrival_unloading' => 'Started',
    'arrival_service' => 'Started',
    'mission_completed' => 'Finished', # legacy
    'mission_done' => 'Finished',
    'departure_gone' => 'Finished', # legacy
    'departure_done' => 'Finished',
    'rest_done' => 'Finished',
    'arrival_arrived' => 'Finished', # legacy
    'arrival_done' => 'Finished',
    'mission_uncompleted' => 'Rejected', # legacy
    'mission_undone' => 'Rejected',
  }

  def check_auth(params)
    rest_client_get(get_user_url(params[:user]), params[:api_key])
  rescue RestClient::Forbidden, RestClient::InternalServerError, RestClient::ResourceNotFound, RestClient::Unauthorized, Errno::ECONNREFUSED
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.invalid_account')}")
  end

  def list_devices(customer, _params = {})
    response = rest_client_get(get_users_url(with_vehicle: true), customer.devices[:fleet][:api_key])
    data = JSON.parse(response.body)

    if response.code == 200 && data['users']
      data['users'].map do |user|
        {
          id: user['sync_user'],
          text: "#{user['name']} - #{user['email']}",
          color: user['color'] || '#000000'
        }
      end
    else
      raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.list')}")
    end
  rescue RestClient::Unauthorized, RestClient::InternalServerError
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.list')}")
  end

  def create_company(customer)
    admin_api_key = Mapotempo::Application.config.devices.fleet.admin_api_key
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.create_company.no_admin_api_key')}") unless admin_api_key

    begin
      # Create company with admin user
      user_email = customer.users.first.email.gsub(/@/, '+admin@')
      company_params = {
        name: customer.name,
        default_locale: customer.users.map(&:locale).compact.first || I18n.locale,
        user_email: user_email
      }

      company = rest_client_with_method(set_company_url, admin_api_key, company_params)
      company = JSON.parse(company)['company']

      # Associate to customer
      customer.update!(devices: customer.devices.merge({
                                                         fleet: {
                                                           enable: true,
                                                           user: user_email,
                                                           api_key: company['admin_user']['api_key']
                                                         }
                                                       }))

      self.api_key = company['admin_user']['api_key']

      return company
    rescue RestClient::UnprocessableEntity => e
      error = JSON.parse(e.response)
      if error['name'] && error['name'][0] == 'has already been taken'
        raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.create_company.already_created')}")
      else
        raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.create_company.error')}")
      end
    rescue RestClient::Unauthorized, RestClient::InternalServerError, RestClient::ResourceNotFound
      raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.create_company.error')}")
    end
  end

  def create_or_update_drivers(customer, current_admin)
    api_key = customer.devices[:fleet][:api_key]
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.create_drivers.no_api_key')}") unless api_key

    user = customer.users.first
    vehicles_with_email = customer.vehicles.select(&:contact_email)

    cache_drivers = {} # Used when multiple vehicle have the same email (When creation)
    drivers = vehicles_with_email.map do |vehicle|
      if vehicle.devices.key?(:fleet_user) && !vehicle.devices[:fleet_user].nil?
        update_driver(vehicle, api_key)
      else
        create_driver(vehicle, api_key, cache_drivers)
      end
    end.compact

    email_drivers = drivers.reject{ |d| d.key?(:updated) }
    UserMailer.send_fleet_drivers(user, I18n.locale, email_drivers, current_admin).deliver_now unless email_drivers.empty?

    drivers
  end

  def create_driver(vehicle, api_key, cache_drivers)
    if !cache_drivers.key?(vehicle.contact_email)
      driver_password = Digest::MD5.hexdigest([vehicle.name, vehicle.contact_email].join(','))[0..3]

      driver_params = {
        name: vehicle.name,
        email: vehicle.contact_email,
        password: driver_password,
        phone: vehicle.phone_number,
        roles: USER_DEFAULT_ROLES,
      }

      begin
        response = rest_client_with_method(set_user_url, api_key, driver_params)
        driver = JSON.parse(response)['user']
        cache_drivers[vehicle.contact_email] = {password: driver_password, fleet_user: driver}

        vehicle.update!(devices: {fleet_user: driver['sync_user']})
        { email: vehicle.contact_email, password: driver_password }
      rescue RestClient::UnprocessableEntity
        nil
      end
    else
      vehicle.update!(devices: {fleet_user: cache_drivers[vehicle.contact_email][:fleet_user]['sync_user']})
      nil
    end
  end

  def update_driver(vehicle, api_key)
    driver_params = {
      name: vehicle.name,
      # email: vehicle.contact_email, waiting for sync_user duplication on fleet
      phone: vehicle.phone_number
    }
    begin
      rest_client_with_method(get_user_url(vehicle.contact_email), api_key, driver_params, :put)
      { email: vehicle.contact_email, updated: true }
    rescue RestClient::UnprocessableEntity, RestClient::Unauthorized, RestClient::InternalServerError, RestClient::ResourceNotFound
      raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.update_drivers.update_failed.')}")
    end
  end

  def get_vehicles_pos(customer)
    response = rest_client_get(get_vehicles_pos_url, customer.devices[:fleet][:api_key])
    data = JSON.parse(response.body)

    if response.code == 200 && data['user_current_locations']
      data['user_current_locations'].map do |current_location|
        {
          fleet_vehicle_id: current_location['sync_user'],
          device_name: current_location['name'],
          lat: current_location['location_detail']['lat'],
          lng: current_location['location_detail']['lon'],
          time: current_location['location_detail']['date'],
          speed: current_location['location_detail']['speed'] && (current_location['location_detail']['speed'].to_f * 3.6).round,
          direction: current_location['location_detail']['bearing']
        }
      end
    else
      raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.get_vehicles_pos')}")
    end
  rescue RestClient::Unauthorized, RestClient::InternalServerError
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.get_vehicles_pos')}")
  end

  def fetch_stops(customer, date, planning)
    responses = [] # Contains all the missions inside the planning's routes
    error = nil

    planning.routes.select(&:vehicle_usage?).each do |route|
      next if route.vehicle_usage.vehicle.devices[:fleet_user].blank? || !route.start

      begin
        response = rest_client_get(
          get_route_url(route.vehicle_usage.vehicle.devices[:fleet_user], generate_route_id(route, p_time(route, route.start)), true),
          customer.devices[:fleet][:api_key]
        )
        response = JSON.parse(response)
        responses += response['route']['missions'] if response['route'].key?('missions')
      rescue RestClient::UnprocessableEntity, RestClient::Unauthorized, RestClient::InternalServerError, RestClient::ResourceNotFound => e
        puts e.inspect
      end
    end

    # return all the missions packed in a comprehensible hash
    responses.map do |mission|
      order_id, date = decode_mission_id(mission['external_ref'])

      {
        mission_type: mission['mission_type'],
        order_id: order_id,
        route_id: decode_route_id_from_mission_ref(mission['external_ref']),
        status: @@order_status[mission['status_type_reference']] || mission['status_type_label'],
        # color: mission['status_type_color'],
        quantities: mission['quantities'],
        eta: mission['eta']
      }
    end.compact
  end

  def fetch_routes_by_date(customer, from, to, sync_user)
    params = {from: from || (Time.zone.now - 12.hour), to: to, user_id: sync_user}
    url = URI::DEFAULT_PARSER.escape("#{api_url}/api/0.1/routes?" + URI.encode_www_form(params.compact))

    begin
      response = JSON.parse rest_client_get(url, customer.devices[:fleet][:api_key], nil), symbolize_names: true
    rescue RestClient::Unauthorized, RestClient::InternalServerError, RestClient::ResourceNotFound, RestClient::UnprocessableEntity
      raise DeviceServiceError, "Mapo. Live: #{I18n.t('errors.fleet.fetch_routes')}"
    end

    response[:routes].map do |r|
      {
        name: r[:name],
        fleet_user: r[:sync_user],
        external_ref: r[:external_ref],
        route_id: decode_route_id_from_route_ref(r[:external_ref]),
        date: r[:date]
      }
    end
  end

  # external_refs: [{fleet_user: "user@gmail.com", external_ref: "cf_format_route"}]
  def clear_routes_by_external_ref(customer, external_refs)
    external_refs.each do |ref|
      begin
        clear_fleet_route(ref['fleet_user'], customer.devices[:fleet][:api_key], ref, true)
      rescue RestClient::Unauthorized, RestClient::InternalServerError, RestClient::ResourceNotFound, RestClient::UnprocessableEntity => e
        puts e.inspect
      end
    end
  end

  def send_route(customer, route, _options = {}, delete_mission = true)
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.past_missions')}") if route.planning.date && route.planning.date < Date.today

    fleet_route = build_route_with_missions(route, customer)
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.no_missions')}") if fleet_route[:missions].empty?

    # FIRST: Try to know if the route has been created in the past
    method = :put
    begin
      get_route(customer.devices[:fleet][:api_key], route.vehicle_usage.vehicle.devices[:fleet_user], fleet_route[:external_ref])
    rescue RestClient::ResourceNotFound
      method = :post
    end

    # SECOND: Call the API
    if method == :put
      update_fleet_route(route.vehicle_usage.vehicle.devices[:fleet_user], customer.devices[:fleet][:api_key], fleet_route, delete_mission)
    else
      send_fleet_route(route.vehicle_usage.vehicle.devices[:fleet_user], customer.devices[:fleet][:api_key], fleet_route, method)
    end
  rescue RestClient::Unauthorized, RestClient::InternalServerError, RestClient::ResourceNotFound, RestClient::UnprocessableEntity
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.set_missions')}")
  end

  def clear_route(customer, route, delete_missions = true)
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.past_missions')}") if route.planning.date && route.planning.date < Date.today

    fleet_route = build_route(route, nil)
    clear_fleet_route(route.vehicle_usage.vehicle.devices[:fleet_user], customer.devices[:fleet][:api_key], fleet_route, delete_missions)
  rescue RestClient::Unauthorized, RestClient::InternalServerError, RestClient::ResourceNotFound, RestClient::UnprocessableEntity
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.clear_missions')}")
  end

  def decode_route_id_from_route_ref(external_ref)
    external_ref.split('-')[1]
  end

  def reporting(api_key, locale, params)
    url = URI::DEFAULT_PARSER.escape("#{api_url}/api/0.1/reportings?#{URI.encode_www_form(params.compact)}")
    begin
      response = RestClient.get(
        url,
        { content_type: :json, charset: 'utf-8', Authorization: 'Token token=' + api_key, 'Accept-Language': locale }
      )
      return nil if response.code == 204

      return response.to_s if params[:format] == 'csv'

      JSON.parse(response.body)
    rescue RestClient::Unauthorized, RestClient::InternalServerError, RestClient::ResourceNotFound, RestClient::UnprocessableEntity => e
      raise DeviceServiceError, "Mapo. Live: #{e.message}"
    rescue RestClient::RequestTimeout, Errno::ECONNREFUSED, SocketError
      raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.timeout')}")
    end
  end

  private

  def get_route(api_key, fleet_user, external_ref)
    rest_client_get(get_route_url(fleet_user, external_ref), api_key)
  end

  def send_fleet_route(user, api_key, fleet_route, method)
    rest_client_with_method(post_routes_url(user), api_key, fleet_route, method)
  end

  def clear_fleet_route(user, api_key, route, delete_missions)
    rest_client_with_method(put_routes_url(user, delete_missions, route[:external_ref]), api_key, route, :delete)
  end

  def update_fleet_route(user, api_key, route, delete_missions)
    rest_client_with_method(put_routes_url(user, delete_missions, route[:external_ref]), api_key, route, :put)
  end

  def rest_client_get(url, api_key, _options = {})
    RestClient.get(
      url,
      { content_type: :json, accept: :json, Authorization: 'Token token=' + api_key }
    )
  rescue RestClient::RequestTimeout, Errno::ECONNREFUSED, SocketError
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.timeout')}")
  end

  def rest_client_with_method(url, api_key, payload, method = :post)
    RestClient::Request.execute(
      method: method,
      url: url,
      headers: { content_type: :json, accept: :json, Authorization: "Token token=#{api_key}" },
      payload: payload.to_json,
      timeout: TIMEOUT_VALUE
    )
  rescue RestClient::RequestTimeout
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.timeout')}")
  end

  def rest_client_delete(url, api_key)
    RestClient::Request.execute(
      method: :delete,
      url: url,
      headers: { content_type: :json, accept: :json, Authorization: "Token token=#{api_key}" },
      timeout: TIMEOUT_VALUE
    )
  rescue RestClient::RequestTimeout
    raise DeviceServiceError.new("Mapo. Live: #{I18n.t('errors.fleet.timeout')}")
  end

  def set_company_url
    URI::DEFAULT_PARSER.escape("#{api_url}/api/0.1/admin/companies")
  end

  def get_users_url(params = {})
    URI::DEFAULT_PARSER.escape(Addressable::Template.new("#{api_url}/api/0.1/users{?with_vehicle*}").expand(params).to_s)
  end

  def get_user_url(user)
    URI::DEFAULT_PARSER.escape("#{api_url}/api/0.1/users/#{convert_user(user)}")
  end

  def set_user_url
    URI::DEFAULT_PARSER.escape("#{api_url}/api/0.1/users")
  end

  def get_vehicles_pos_url
    URI::DEFAULT_PARSER.escape("#{api_url}/api/0.1/user_current_locations")
  end

  def delete_missions_url(user, destination_ids)
    URI::DEFAULT_PARSER.escape("#{api_url}/api/0.1/missions/?user_id=#{convert_user(user)}&#{destination_ids.to_query('ids')}")
  end

  def post_routes_url(user)
    URI::DEFAULT_PARSER.escape("#{api_url}/api/0.1/routes?user_id=#{convert_user(user)}")
  end

  def put_routes_url(_user, delete_missions, route_id)
    URI::DEFAULT_PARSER.escape("#{api_url}/api/0.1/routes/#{route_id}?delete_missions=#{delete_missions}")
  end

  def get_route_url(user, route_id, with_missions = false)
    URI::DEFAULT_PARSER.escape("#{api_url}/api/0.1/routes/#{route_id}?user_id=#{convert_user(user)}&with_missions=#{with_missions}")
  end

  def generate_store_id(store, route, date, options)
    "#{options[:type]}-#{store.id}-#{date.strftime('%Y_%m_%d')}-#{route.id}"
  end

  def generate_mission_id(stop, date)
    order_id = if stop.is_a?(StopVisit)
      ref = [stop.visit.ref, stop.ref].compact.join('-')
      (ref.blank? ? '' : ref + '-') + "v#{stop.visit_id}"
    else
      "r#{stop.id}"
    end
    "mission-#{order_id}-#{date.strftime('%Y_%m_%d')}-#{stop.route.id}"
  end

  def generate_route_id(route, route_date)
    "route-#{route.id}-#{route_date.strftime('%Y_%m_%d')}"
  end

  def convert_user(user)
    # Convert to SHA256 if user is a email address
    user && user.include?('@') ? Digest::SHA256.hexdigest(user) : user
  end

  def decode_mission_id(mission_ref)
    # if ext_ref's last element contains underscores then route.id is missing
    parts = mission_ref.split('-')
    if parts.last.include?('_')
      parts[-2..-1]
    else
      parts[-3..-2]
    end
  end

  # Return the route_id only if the current external ref isn't obsolete
  def decode_route_id_from_mission_ref(mission_ref)
    parts = mission_ref.split('-')
    mission_ref.split('-').last if parts.length > 3
  end
end
