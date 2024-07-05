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

class V01::Zonings < Grape::API
  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def zoning_params(d_params = nil)
      p = ActionController::Parameters.new(d_params || params)
      p = p[:zoning] if p.key?(:zoning)
      if p[:zones]
        p[:zones_attributes] = p[:zones]
        p[:zones_attributes].each{ |z|
          z[:polygon] = Sanitize.clean(z[:polygon].to_json) if z[:polygon].is_a?(Hash) || z[:polygon].is_a?(ActionController::Parameters)
        }
      end
      # Deals with deprecated speed_multiplicator
      p[:speed_multiplier] = p.delete[:speed_multiplicator] if p[:speed_multiplicator]
      p.permit(:name, zones_attributes: [:id, :name, :polygon, :_destroy, :vehicle_id, :speed_multiplier])
    end
  end

  resource :zonings do
    desc 'Fetch customer\'s zonings.',
      nickname: 'getZonings',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::Zoning),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :ids, type: Array[Integer], desc: 'Select returned zonings by id.', coerce_with: CoerceArrayInteger
    end
    get do
      zonings = if params.key?(:ids)
        current_customer.zonings.select{ |zoning| params[:ids].include?(zoning.id) }
      else
        current_customer.zonings.load
      end
      present zonings, with: V01::Entities::Zoning
    end

    desc 'Fetch zoning.',
      nickname: 'getZoning',
      success: V01::Status.success(:code_200, V01::Entities::Zoning),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    get ':id' do
      present current_customer.zonings.find(params[:id]), with: V01::Entities::Zoning
    end

    desc 'Create zoning.',
      detail: 'Create a new empty zoning. Zones will can be created for this zoning thereafter.',
      nickname: 'createZoning',
      success: V01::Status.success(:code_201, V01::Entities::Zoning),
      failure: V01::Status.failures
    params do
      requires :name, type: String
      optional :zones, type: Array, documentation: { param_type: 'body' } do use :request_zone end
    end
    post do
      d_params = declared(params, include_missing: false)
      zoning = current_customer.zonings.build(zoning_params(d_params))
      zoning.zones = SimplifyGeometry.dump_multipolygons(zoning)
      zoning.save!
      present zoning, with: V01::Entities::Zoning
    end

    desc 'Update zoning.',
      nickname: 'updateZoning',
      success: V01::Status.success(:code_200, V01::Entities::Zoning),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      optional :name, type: String
      optional :zones, type: Array, documentation: { param_type: 'body' } do use :request_zone end
    end
    put ':id' do
      d_params = declared(params, include_missing: false)
      zoning = current_customer.zonings.find(params[:id])
      zoning.update! zoning_params(d_params)
      SimplifyGeometry.dump_multipolygons(zoning, true)
      present zoning, with: V01::Entities::Zoning
    end

    desc 'Delete zoning.',
      nickname: 'deleteZoning',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    delete ':id' do
      current_customer.zonings.find(params[:id]).destroy
      status 204
    end

    desc 'Delete multiple zonings.',
      nickname: 'deleteZonings',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :ids, type: Array[Integer], coerce_with: CoerceArrayInteger
    end
    delete do
      Zoning.transaction do
        current_customer.zonings.select{ |zoning| params[:ids].include?(zoning.id) }.each(&:destroy)
        status 204
      end
    end

    desc 'Generate zoning from planning.',
      detail: 'Create new automatic zones in current zoning for a dedicated planning. Only stops in a route with vehicle are taken into account. All previous existing zones are cleared. Each generated zone is linked to a dedicated vehicle.',
      nickname: 'generateFromPlanning',
      success: V01::Status.success(:code_200, V01::Entities::Zoning),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      requires :planning_id, type: Integer
    end
    patch ':id/from_planning/:planning_id' do
      Zoning.transaction do
        zoning = current_customer.zonings.find(params[:id])
        planning = current_customer.plannings.find(params[:planning_id])
        if planning
          zoning.from_planning(planning)
          zoning.save!
          present zoning, with: V01::Entities::Zoning
        end
      end
    end

    desc 'Generate zoning automatically.',
      detail: 'Create #N new automatic zones in current zoning for a dedicated planning (#N should be less or egal your vehicle\'s fleet size). All planning\'s stops (or all visits from destinations if there is no planning linked to this zoning) are taken into account, even if they are out of route. All previous existing zones are cleared. Each generated zone is linked to a dedicated vehicle.',
      nickname: 'generateAutomatic',
      success: V01::Status.success(:code_200, V01::Entities::Zoning),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      requires :planning_id, type: Integer
      optional :n, type: Integer, desc: 'Number of produced zones. Default to vehicles number.'
    end
    patch ':id/automatic/:planning_id' do
      Zoning.transaction do
        zoning = current_customer.zonings.find(params[:id])
        planning = current_customer.plannings.find(params[:planning_id])
        n = params.key?(:n) ? Integer(params[:n]) : nil
        if planning
          zoning.automatic_clustering(planning, n)
          zoning.save!
          present zoning, with: V01::Entities::Zoning
        end
      end
    end

    desc 'Generate isochrones.',
      detail: 'Generate zoning with isochrone polygons for all vehicles. All previous existing zones are cleared.',
      nickname: 'generateIsochrone',
      success: V01::Status.success(:code_200, V01::Entities::Zoning),
      failure: V01::Status.failures(override: {code_404: 'VehicleUsageSet not found' })
    params do
      requires :id, type: Integer
      requires :size, type: Integer, desc: 'Area accessible from the start store by this travel time in seconds.'
      optional :vehicle_usage_set_id, type: Integer, desc: 'If not provided, use one or the only one vehicle_usage_set.'
      optional :departure_date, type: Date, desc: 'Departure date (only used if router supports traffic). Open time for each vehicle is used in addition of this date.'
    end
    patch ':id/isochrone' do
      Zoning.transaction do
        zoning = current_customer.zonings.where(id: params[:id]).first!
        vehicle_usage_set = if params.key?(:vehicle_usage_set_id)
          vehicle_usage_set_id = Integer(params[:vehicle_usage_set_id])
          current_customer.vehicle_usage_sets.to_a.find{ |vehicle_usage_set| vehicle_usage_set.id == vehicle_usage_set_id }
        else
          current_customer.vehicle_usage_sets[0]
        end
        size = Integer(params[:size])
        if vehicle_usage_set
          zoning.isochrones(size, vehicle_usage_set, params[:departure_date])
          zoning.save!
          present zoning, with: V01::Entities::Zoning
        else
          error! V01::Status.code_response(:code_404, before: 'VehicleUsageSet'), 404
        end
      end
    end

    desc 'Generate isochrone for only one vehicle usage.',
      detail: 'Generate zoning with isochrone polygon from specified vehicle\'s start.',
      nickname: 'generateIsochroneVehicleUsage',
      success: V01::Status.success(:code_200, V01::Entities::Zone),
      failure: V01::Status.failures(override: {code_404: 'VehicleUsage not found' })
    params do
      requires :id, type: Integer
      requires :size, type: Integer, desc: 'Area accessible from the start store by this travel time in seconds.'
      requires :vehicle_usage_id, type: Integer
      optional :departure_date, type: Date, desc: 'Departure date (only used if router supports traffic). Open time of the vehicle is used in addition of this date.'
    end
    patch ':id/vehicle_usage/:vehicle_usage_id/isochrone' do
      Zoning.transaction do
        zoning = current_customer.zonings.where(id: params[:id]).first!
        vehicle_usage_id = Integer(params[:vehicle_usage_id])
        vehicle_usage = current_customer.vehicle_usage_sets.collect{ |vehicle_usage_set|
          vehicle_usage_set.vehicle_usages.find{ |vehicle_usage|
            vehicle_usage.id == vehicle_usage_id
          }
        }.compact.first
        size = Integer(params[:size])
        if vehicle_usage
          # Use Time.zone.parse to preserve time zone from user (instead of to_time)
          zoning.isochrone(size, vehicle_usage, nil, !params[:departure_date].blank? && Time.zone.parse(params[:departure_date].to_s) + vehicle_usage.default_time_window_start)
          zoning.save!
          present zoning.zones.find{ |z| z.vehicle == vehicle_usage.vehicle }, with: V01::Entities::Zone
        else
          error! V01::Status.code_response(:code_404, before: 'VehicleUsage'), 404
        end
      end
    end

    desc 'Generate isodistances.',
      detail: 'Generate zoning with isodistance polygons for all vehicles. All previous existing zones are cleared.',
      nickname: 'generateIsodistance',
      success: V01::Status.success(:code_200, V01::Entities::Zoning),
      failure: V01::Status.failures(override: {code_404: 'VehicleUsageSet not found'})
    params do
      requires :id, type: Integer
      requires :size, type: Integer, desc: 'Area accessible from the start store by this travel distance in meters.'
      optional :vehicle_usage_set_id, type: Integer, desc: 'If not provided, use one or the only one vehicle_usage_set.'
      optional :departure_date, type: Date, desc: 'Departure date (only used if router supports traffic). Open time for each vehicle is used in addition of this date.'
    end
    patch ':id/isodistance' do
      Zoning.transaction do
        zoning = current_customer.zonings.where(id: params[:id]).first!
        vehicle_usage_set = if params.key?(:vehicle_usage_set_id)
          vehicle_usage_set_id = Integer(params[:vehicle_usage_set_id])
          current_customer.vehicle_usage_sets.to_a.find{ |vehicle_usage_set| vehicle_usage_set.id == vehicle_usage_set_id }
        else
          current_customer.vehicle_usage_sets[0]
        end
        size = Integer(params[:size])
        if vehicle_usage_set
          zoning.prefered_unit = @current_user.prefered_unit
          zoning.isodistances(size, vehicle_usage_set, params[:departure_date])
          zoning.save!
          present zoning, with: V01::Entities::Zoning
        else
          error! V01::Status.code_response(:code_404, before: 'VehicleUsageSet'), 404
        end
      end
    end

    desc 'Generate isodistance for only one vehicle usage.',
      detail: 'Generate zoning with isodistance polygon from specified vehicle\'s start.',
      nickname: 'generateIsodistanceVehicleUsage',
      success: V01::Status.success(:code_200, V01::Entities::Zone),
      failure: V01::Status.failures(override: {code_404: 'VehicleUsage not found'})
    params do
      requires :id, type: Integer
      requires :size, type: Integer, desc: 'Area accessible from the start store by this travel distance in meters.'
      requires :vehicle_usage_id, type: Integer
      optional :departure_date, type: Date, desc: 'Departure date (only used if router supports traffic). Open time of the vehicle is used in addition of this date.'
    end
    patch ':id/vehicle_usage/:vehicle_usage_id/isodistance' do
      Zoning.transaction do
        zoning = current_customer.zonings.where(id: params[:id]).first!
        vehicle_usage_id = Integer(params[:vehicle_usage_id])
        vehicle_usage = current_customer.vehicle_usage_sets.collect{ |vehicle_usage_set|
          vehicle_usage_set.vehicle_usages.find{ |vehicle_usage|
            vehicle_usage.id == vehicle_usage_id
          }
        }.compact.first
        size = Integer(params[:size])
        if vehicle_usage
          zoning.prefered_unit = @current_user.prefered_unit
          # Use Time.zone.parse to preserve time zone from user (instead of to_time)
          zoning.isodistance(size, vehicle_usage, nil, !params[:departure_date].blank? && Time.zone.parse(params[:departure_date].to_s) + vehicle_usage.default_time_window_start)
          zoning.save!
          present zoning.zones.find{ |z| z.vehicle == vehicle_usage.vehicle }, with: V01::Entities::Zone
        else
          error! V01::Status.code_response(:code_404, before: 'VehicleUsage'), 404
        end
      end
    end

    desc 'Build isochrone for a point.',
      detail: 'Build isochrone polygon from a specific point. No zoning is saved in database.',
      nickname: 'buildIsochrone',
      success: V01::Status.success(:code_200, V01::Entities::Zoning),
      failure: V01::Status.failures
    params do
      requires :lat, type: Float, desc: 'Latitude.'
      requires :lng, type: Float, desc: 'Longitude.'
      requires :size, type: Integer, desc: 'Area accessible from the start point by this travel time in seconds.'
      optional :vehicle_usage_id, type: Integer, desc: 'If not provided, use default router from customer.'
      optional :departure, type: DateTime, desc: 'Departure time (only used if router supports traffic)'
    end
    patch 'isochrone' do
      zoning = Zoning.new customer_id: current_customer.id
      vehicle_usage = current_customer.vehicle_usage_sets.collect{ |vehicle_usage_set|
        vehicle_usage_set.vehicle_usages.find{ |vehicle_usage|
          vehicle_usage.id == params[:vehicle_usage_id]
        }
      }.compact.first
      size = Integer(params[:size])
      zoning.isochrone(size, vehicle_usage, [params[:lat], params[:lng]], params[:departure])
      present zoning, with: V01::Entities::Zoning
    end

    desc 'Build isodistance for a point.',
      detail: 'Build isodistance polygon from a specific point. No zoning is saved in database.',
      nickname: 'buildIsodistance',
      success: V01::Status.success(:code_200, V01::Entities::Zoning),
      failure: V01::Status.failures
    params do
      requires :lat, type: Float, desc: 'Latitude.'
      requires :lng, type: Float, desc: 'Longitude.'
      requires :size, type: Integer, desc: 'Area accessible from the start point by this travel distance in meters.'
      optional :vehicle_usage_id, type: Integer, desc: 'If not provided, use default router from customer.'
      optional :departure, type: DateTime, desc: 'Departure time (only used if router supports traffic)'
    end
    patch 'isodistance' do
      zoning = Zoning.new customer_id: current_customer.id
      vehicle_usage = current_customer.vehicle_usage_sets.collect{ |vehicle_usage_set|
        vehicle_usage_set.vehicle_usages.find{ |vehicle_usage|
          vehicle_usage.id == params[:vehicle_usage_id]
        }
      }.compact.first
      size = Integer(params[:size])
      zoning.prefered_unit = @current_user.prefered_unit
      zoning.isodistance(size, vehicle_usage, [params[:lat], params[:lng]], params[:departure])
      present zoning, with: V01::Entities::Zoning
    end

    desc 'Fetch the destinations by zonning.',
      detail: 'Fetch the destinations by zonning.',
      nickname: 'destinationsByZonning',
      is_array: true,
      http_codes: [
        V01::Status.success(:code_200, V01::Entities::ZoningDestinations),
        V01::Status.success(:code_204)
      ].concat(V01::Status.failures)
    params do
      requires :id, type: Integer
    end
    get ':id/destinations' do
      zoning = current_customer.zonings.find(params[:id])

      zones_destinations = zoning.apply(current_customer.visits).select{ |zone, visits| !zone.nil? }.collect{ |zone, visits|
        OpenStruct.new(zone.attributes.merge(destinations: visits.collect(&:destination).uniq))
      }
      zoning_destinations = OpenStruct.new(zoning.attributes.merge(zones: zones_destinations))
      present zoning_destinations, with: V01::Entities::ZoningDestinations
    end

    desc 'Find the zone where a point belongs to.',
      detail: 'Find the closest zone for the specified coordinates.',
      nickname: 'polygonByPoint',
      http_codes: [
        V01::Status.success(:code_200, V01::Entities::Zone),
        V01::Status.success(:code_204)
      ].concat(V01::Status.failures)
    params do
      requires :lat, type: Float, desc: 'Latitude.'
      requires :lng, type: Float, desc: 'Longitude.'
    end
    get ':id/polygon_by_point' do
      zoning = current_customer.zonings.where(id: params[:id]).first!

      zone, pip_distance = zoning.zones.map{ |zone|
        [zone, zone.inside_distance(params[:lat], params[:lng]) || 0]
      }.max_by{ |_zone, pip_distance|
        pip_distance
      }

      if zone && pip_distance > 0
        present zone, with: V01::Entities::Zone
      else
        status 204
      end
    end

  end
end
