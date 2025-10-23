# Copyright © Mapotempo, 2014-2015
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
require 'coerce'

require Rails.root.join('app/api/v01/devices/device_helpers')
include V01::Devices::DeviceHelpers
include DeliverableByVehiclesHelper
class V01::Vehicles < Grape::API

  rescue_from DeviceServiceError do |e|
    error! e.message, 200
  end

  helpers SharedParams
  helpers do
    def session
      env[Rack::RACK_SESSION]
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def vehicle_params(vehicle_customer = nil)
      p = ActionController::Parameters.new(params)
      p = p[:vehicle] if p.key?(:vehicle)
      p[:capacities] = Hash[p[:capacities].map { |q| [q[:deliverable_unit_id].to_s, q[:quantity]] }] if p[:capacities]

      customer = vehicle_customer || current_customer || @current_user.admin? && @current_user.reseller.customers.where(id: params[:customer_id]).first!
      # Deals with deprecated capacity
      unless p[:capacities]
        # p[:capacities] keys must be string here because of permit below
        p[:capacities] = { customer.deliverable_units[0].id.to_s => p.delete(:capacity) } if p[:capacity] && customer.deliverable_units.size > 0
        if p[:capacity1_1] || p[:capacity1_2]
          p[:capacities] = {}
          p[:capacities] = p[:capacities].merge({ customer.deliverable_units[0].id.to_s => p.delete(:capacity1_1) }) if p[:capacity1_1] && customer.deliverable_units.size > 0
          p[:capacities] = p[:capacities].merge({ customer.deliverable_units[1].id.to_s => p.delete(:capacity1_2) }) if p[:capacity1_2] && customer.deliverable_units.size > 1
        end
      end
      # Deals with deprecated speed_multiplicator
      p[:speed_multiplier] = p.delete[:speed_multiplicator] if p[:speed_multiplicator] && !p[:speed_multiplier]
      nested_attributes = customer.custom_attributes.map(&:name)
      p.permit(:contact_email, :phone_number, :ref, :name, :emission, :consumption, :color, :router_id, :router_dimension, :max_distance, :max_ride_distance, :max_ride_duration, :speed_multiplier, :history_cron_hour, router_options: [:time, :distance, :isochrone, :isodistance, :traffic, :avoid_zones, :track, :motorway, :toll, :trailers, :weight, :weight_per_axle, :height, :width, :length, :hazardous_goods, :max_walk_distance, :approach, :snap, :strict_restriction], capacities: customer.deliverable_units.map{ |du| du.id.to_s }, capacities_initial_loads: customer.deliverable_units.map{ |du| du.id.to_s }, devices: permit_devices, tag_ids: [], custom_attributes: nested_attributes)
    end

    def permit_devices
      permit = []
      Planner::Application.config.devices.to_h.each{ |device_name, device_object|
        if device_object.respond_to?('definition')
          device_definition = device_object.definition
          if device_definition.key?(:forms) && device_definition[:forms].key?(:vehicle)
            device_definition[:forms][:vehicle].keys.each{ |key|
              permit << key
            }
          end
        end
      }
      permit
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def vehicle_usage_params
      p = ActionController::Parameters.new(params)
      p = p[:vehicle] if p.key?(:vehicle)
      p[:time_window_start] = p.delete(:open) if p[:open]
      p[:time_window_end] = p.delete(:close) if p[:close]
      p.permit(:cost_distance, :cost_fixed, :cost_time, :time_window_start, :time_window_end, :store_start_id, :store_stop_id, :store_duration, :store_rest_id, :rest_start, :rest_stop, :rest_duration, tag_ids: [])
    end

    def deliverables_by_vehicle_params
      p = ActionController::Parameters.new(params)
      p.permit(:id, :planning_ids)
    end
  end

  resource :vehicles do
    desc 'Fetch customer\'s vehicles.',
      nickname: 'getVehicles',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::Vehicle),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :ids, type: Array[String], desc: 'Select returned vehicles by id separated with comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
    end
    get do
      vehicles = if params.key?(:ids)
        current_customer.vehicles.select{ |vehicle|
          params[:ids].any?{ |s| ParseIdsRefs.match(s, vehicle) }
        }
      else
        current_customer.vehicles.load
      end
      present vehicles, with: V01::Entities::Vehicle
    end

    desc 'Get vehicle\'s positions.',
      detail: 'Only available if enable_vehicle_position is true for customer.',
      nickname: 'currentPosition',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::VehiclePosition),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :ids, type: Array[Integer]
    end
    get 'current_position' do
      customer = current_customer
      vehicles = customer.vehicles.find params[:ids]
      positions = []
      errors = []
      begin
        Planner::Application.config.devices.to_h.each{ |key, device|
          if customer.device.configured?(key)
            options = {customer: customer}
            if key == :teksat
              teksat_authenticate customer # Required to set a session variable needed for teksat Api
              options[:ticket_id] = session[:teksat_ticket_id]
            end
            service = Object.const_get(device.class.name + 'Service').new(options)
            if service.respond_to?(:vehicle_pos)
              if device.definition[:forms][:vehicle].try(&:length) && device.definition[:forms][:vehicle].length > 0
                (service.vehicle_pos || []).each do |item|
                  vehicle_id = item.delete "#{key}_vehicle_id".to_sym
                  vehicle = vehicles.detect{ |v| v.devices[device.definition[:forms][:vehicle].keys.first] == vehicle_id }
                  next unless vehicle
                  positions << item.merge(vehicle_id: vehicle.id)
                end
              else
                positions += service.vehicle_pos
              end
            end
          end
        }
      rescue DeviceServiceError => e
        errors << e.message
      end
      if errors.any?
        { errors: errors }
      else
        present positions, with: V01::Entities::VehiclePosition
      end
    end

    desc 'Get vehicle\'s temperatures.',
      detail: 'return vehicle temperature',
      nickname: 'getTemperature',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::VehicleTemperature),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :ids, type: Array[Integer]
    end
    get 'temperature' do
      customer = current_customer
      temperatures = []
      errors = []
      begin
        if customer.device.configured?(:sopac)
          device = Planner::Application.config.devices[:sopac]
          service = Object.const_get(device.class.name + 'Service').new(options)
          if service.respond_to?(:vehicles_temperature)
            temperatures += service.vehicles_temperature(customer)
          end
        end
      rescue DeviceServiceError => e
        errors << e.message
      end
      if errors.any?
        { errors: errors }
      else
        present temperatures, with: V01::Entities::VehicleTemperature
      end
    end

    desc 'Fetch vehicle.',
      nickname: 'getVehicle',
      success: V01::Status.success(:code_200, V01::Entities::Vehicle),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
    end
    get ':id' do
      present current_customer.vehicles.where(ParseIdsRefs.where(Vehicle, [params[:id]])).first!, with: V01::Entities::Vehicle
    end

    desc 'Update vehicle.',
      nickname: 'updateVehicle',
      success: V01::Status.success(:code_200, V01::Entities::Vehicle),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
      use :request_vehicle
    end
    put ':id' do
      params[:tag_ids] = filter_tag_ids_belong_to_customer(params[:tag_ids], current_customer) if params[:tag_ids]
      vehicle = current_customer.vehicles.where(ParseIdsRefs.where(Vehicle, [params[:id]])).first!
      vehicle.update! vehicle_params
      present vehicle, with: V01::Entities::Vehicle
    end

    detailCreate = 'For each new created Vehicle and VehicleUsageSet a new VehicleUsage will be created at the same time (i.e. customer has 2 VehicleUsageSets \'Morning\' and \'Evening\', a new Vehicle is created: 2 new VehicleUsages will be automatically created with the new vehicle).'
    if Planner::Application.config.manage_vehicles_only_admin
      detailCreate = 'Only available with an admin api_key. ' + detailCreate
    end
    desc "Create vehicle#{Planner::Application.config.manage_vehicles_only_admin ? ' (admin)' : ''}.",
      detail: detailCreate,
      nickname: 'createVehicle',
      success: V01::Status.success(:code_201, V01::Entities::Vehicle),
      failure: V01::Status.failures
    params do
      if Planner::Application.config.manage_vehicles_only_admin
        requires :customer_id, type: Integer
      end

      use :request_vehicle
      use :request_vehicle_usage
    end
    post do
      params[:tag_ids] = filter_tag_ids_belong_to_customer(params[:tag_ids], current_customer) if params[:tag_ids]
      if Planner::Application.config.manage_vehicles_only_admin
        if @current_user.admin?
          customer = @current_user.reseller.customers.where(id: params[:customer_id]).first!
          vehicle = customer.vehicles.create(vehicle_params(customer))
          vehicle.vehicle_usages.each { |u|
            u.assign_attributes(vehicle_usage_params)
          }
          vehicle.save!
        else
          error! V01::Status.code_response(:code_403), 403
        end
      else
        vehicle = current_customer.vehicles.create(vehicle_params)
        vehicle.vehicle_usages.each { |u|
          u.assign_attributes(vehicle_usage_params)
        }
        vehicle.save!
      end
      present vehicle, with: V01::Entities::Vehicle
    end

    detailDelete = Planner::Application.config.manage_vehicles_only_admin ? 'Only available with an admin api_key.' : nil
    desc "Delete vehicle#{Planner::Application.config.manage_vehicles_only_admin ? ' (admin)' : ''}.",
      detail: detailDelete,
      nickname: 'deleteVehicle',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
    end
    delete ':id' do
      if Planner::Application.config.manage_vehicles_only_admin
        if @current_user.admin?
          vehicle = Vehicle.for_reseller_id(@current_user.reseller.id).where(ParseIdsRefs.where(Vehicle, [params[:id]])).first!
          vehicle.destroy!
          status 204
        else
          error! V01::Status.code_response(:code_403), 403
        end
      else
        current_customer.vehicles.where(ParseIdsRefs.where(Vehicle, [params[:id]])).first!.destroy!
        status 204
      end
    end

    desc "Delete multiple vehicles#{Planner::Application.config.manage_vehicles_only_admin ? ' (admin)' : ''}.",
      detail: detailDelete,
      nickname: 'deleteVehicles',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :ids, type: Array[String], desc: 'Ids separated by comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
    end
    delete do
      Vehicle.transaction do
        if Planner::Application.config.manage_vehicles_only_admin || @current_user.admin?
          if @current_user.admin?
            Vehicle.for_reseller_id(@current_user.reseller.id).select{ |vehicle|
              params[:ids].any?{ |s| ParseIdsRefs.match(s, vehicle) }
            }.each(&:destroy!)
            status 204
          else
            error! V01::Status.code_response(:code_403), 403
          end
        else
          current_customer.vehicles.select{ |vehicle|
            params[:ids].any?{ |s| ParseIdsRefs.match(s, vehicle) }
          }.each(&:destroy!)
          status 204
        end
      end
    end

    desc 'Fetch deliverables by vehicle for select plans',
      detail: 'Get list of deliverable for a vehicle on each selected plans',
      nickname: 'getDeliverablesByVehicles',
      success: V01::Entities::Layer
    params do
      requires :id, type: Integer, desc: 'Vehicle ID'
      requires :planning_ids, type: String, desc: 'Plannings ids'
    end
    get ':id/deliverable_units' do
      p = deliverables_by_vehicle_params

      deliverable_units = current_customer.deliverable_units
      plannings = plannings_by_ids(current_customer, p[:planning_ids])

      routes = routes_by_vehicle(plannings, p[:id])
      routes_quantities = routes_quantities_by_deliverables(routes, deliverable_units)

      data = {
        plannings: plannings,
        routes_quantities: routes_quantities,
        routes_total_infos: routes_total_infos(routes_quantities, routes)
      }

      present data, with: V01::Entities::DeliverablesByVehicles
    end
  end
end
