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
require 'coerce'

class V01::Destinations < Grape::API
  helpers SharedParams
  helpers ConvertDeprecatedHelper
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def destination_params
      visit_ref_ids = {}
      existing_destination = nil
      p = ActionController::Parameters.new(params)
      p = p[:destination] if p.key?(:destination)
      if p[:visits]
        p[:visits_attributes] = p[:visits]
      end
      if p[:id] && p[:visits_attributes]&.any?{ |visit_attr| visit_attr.key?(:ref) && !visit_attr.key?(:id)}
        existing_destination = current_customer.destinations.find_by_id(p[:id])
        existing_destination.visits.where.not(ref: nil).each{ |visit|
          visit_ref_ids[visit.ref] = visit.id
        } if existing_destination
      end
      if p[:visits_attributes]
        p[:visits_attributes].each do |hash|
          convert_timewindows(hash)
          convert_deprecated_quantities(hash, current_customer.deliverable_units)
          hash[:id] = visit_ref_ids[hash[:ref]] if existing_destination && !hash.key?(:id) && hash[:ref].present? && visit_ref_ids[hash[:ref]]

          # Serialize quantities
          if hash[:quantities]
            hash[:quantities] = hash[:quantities].reject { |q| q.blank? }
            if hash[:quantities].any?
              hash[:pickups] = {}
              hash[:deliveries] = {}
              hash[:quantities].each{ |q|
                hash[:pickups][q[:deliverable_unit_id].to_s] = q[:pickup] if q[:pickup]
                hash[:pickups][q[:deliverable_unit_id].to_s] = q[:quantity].abs if q[:quantity] && q[:quantity] < 0
                hash[:deliveries][q[:deliverable_unit_id].to_s] = q[:quantity] if q[:quantity] && q[:quantity] > 0
                hash[:deliveries][q[:deliverable_unit_id].to_s] = q[:delivery] if q[:delivery]
              }
            end
            hash.delete(:quantities)
          end
        end
      end

      deliverable_unit_ids = current_customer.deliverable_units.map{ |du| du.id.to_s }
      nested_visit_custom_attributes = current_customer.custom_attributes.for_visit.map(&:name)
      p.permit(:ref, :name, :street, :detail, :postalcode, :city, :state, :country, :lat, :lng, :comment, :phone_number, :geocoding_accuracy, :geocoding_level, tag_ids: [], visits_attributes: [:id, :ref, :duration, :time_window_start_1, :time_window_end_1, :time_window_start_2, :time_window_end_2, :priority, :revenue, :force_position, tag_ids: [], pickups: deliverable_unit_ids, deliveries: deliverable_unit_ids, custom_attributes: nested_visit_custom_attributes])
    end

    def present_geojson_destinations(params)
      destinations = if params.key?(:ids)
        ids = params[:ids].split(',')
        current_customer.destinations.includes_visits.select{ |destination|
          params[:ids].any?{ |s| ParseIdsRefs.match(s, destination) }
        }
      else
        current_customer.destinations.includes_visits
      end
      '{"type":"FeatureCollection","features":[' + destinations.select(&:position?).map { |d|
          feat = {
            type: 'Feature',
            geometry: {
              type: 'Point',
              coordinates: [d.lng.round(6), d.lat.round(6)]
            },
            properties: {
              destination_id: d.id,
              color: d.visits_color,
              icon: d.visits_icon,
              icon_size: d.visits_icon_size
            }
          }
          feat[:properties][:quantities] = d.visits.map { |v|
            with_quantities(v)
          }.flatten if params[:quantities]
        feat[:properties][:nb_visit] = d.visits.length
        feat.to_json
      }.compact.join(',') + ']}'
    end

    def with_quantities(visit)
      units = visit.destination.customer.deliverable_units
      quantities = []

      units.each { |unit|

        quantity = { deliverable_unit_id: unit.id }

        if visit.default_deliveries[unit.id]
          quantity[:delivery] = visit.default_deliveries[unit.id]
        end

        if visit.default_pickups[unit.id]
          quantity[:pickup] = visit.default_pickups[unit.id]
        end

        next if quantity[:delivery].nil? && quantity[:pickup].nil?

        quantity[:quantity] = (quantity[:delivery] || 0) - (quantity[:pickup] || 0)

        quantities << quantity
      }

      quantities
    end
  end

  resource :destinations do
    desc 'Fetch customer\'s destinations.',
      nickname: 'getDestinations',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::Destination),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :ids, type: Array[String], desc: 'Select returned destinations by id separated with comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
      optional :quantities, type: Boolean, default: false, desc: 'Include the quantities when using geojson output.'
    end
    get do
      if env['api.format'] == :geojson
        present_geojson_destinations params
      else
        destinations = if params.key?(:ids)
          current_customer.destinations.includes_visits.select{ |destination|
            params[:ids].any?{ |s| ParseIdsRefs.match(s, destination) }
          }
        else
          current_customer.destinations.includes_visits.load
        end
        present destinations, with: V01::Entities::Destination
      end
    end

    desc 'Fetch destination.',
      nickname: 'getDestination',
      success: V01::Status.success(:code_200, V01::Entities::Destination),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
    end
    get ':id' do
      id = ParseIdsRefs.read(params[:id])
      present current_customer.destinations.includes_visits.where(id).first!, with: V01::Entities::Destination
    end

    desc 'Create destination.',
      nickname: 'createDestination',
      success: V01::Status.success(:code_201, V01::Entities::Destination),
      failure: V01::Status.failures
    params do
      use(:request_destination, skip_visit_id: true)
    end
    post do
      raise Exceptions::JobInProgressError if current_customer.job_optimizer

      destination = current_customer.destinations.build(destination_params)
      destination.save!
      current_customer.save!
      present destination, with: V01::Entities::Destination
    end

    desc 'Import destinations by upload a CSV file, by JSON or from TomTom.',
      detail: 'Import multiple destinations and visits. Use your internal and unique ids as a "reference" to automatically retrieve and update objects. If "route" key is provided for a visit or if a planning attribute is sent, a planning will be automatically created at the same time. If all "route" attibutes are blank or none attribute for planning is sent, only destinations and visits will be created/updated.',
      nickname: 'importDestinations',
      is_array: true,
      http_codes: [
        V01::Status.success(:code_202, V01::Entities::Destination),
        V01::Status.success(:code_200, V01::Entities::Destination)
      ].concat(V01::Status.failures(is_array: true, add: [:code_422]))
    params do
      optional(:replace, type: Boolean, documentation: {param_type: 'form'})
      optional(:file, type: CSVFile, desc: 'CSV file, encoding, separator and line return automatically detected, with localized CSV header according to HTTP header Accept-Language.', documentation: {param_type: 'form'})
      optional(:remote, type: Symbol, values: [:tomtom], documentation: {param_type: 'form'})
      optional(:planning, type: Hash, documentation: { param_type: 'body' }, desc: 'Planning definition in case of planning created in the same time of destinations import. Planning is created if "route" field is provided in CVS or Json.') do
        optional(:name, type: String)
        optional(:ref, type: String)
        optional(:date, type: String)
        optional(:vehicle_usage_set_id, type: Integer)
        optional(:zoning_ids, type: Array[Integer], desc: 'If a new zoning is specified before planning save, all visits will be affected to vehicles specified in zones.')
      end
      optional(:destinations, type: Array, documentation: { param_type: 'body' }, desc: 'In mutual exclusion with CSV file upload and remote. the destinations might be Destinations with Visits or Stores') do
        use(:request_destination, skip_visit_id: true, json_import: true)
        use(:request_store)
        optional(:stop_type, type: String, default: nil, values: ['visit', 'store'], desc: 'Type of the stop if the entry is associated to a planning')
        optional(:route, type: String, default: nil, desc: 'Route name to add the destination to if associated to a planning')
        optional(:ref_vehicle, type: String, desc: 'Vehicle reference to add the destination to if associated to a planning')
        optional(:active, type: Boolean, desc: 'If the destination is active if associated to a planning')
        optional(:stop_custom_attributes, type: Hash, desc: 'Custom attributes to add to the destination')
      end

      exactly_one_of :file, :destinations, :remote
    end
    put do
      raise Exceptions::JobInProgressError if current_customer.job_optimizer

      if params[:destinations]
        d_params = declared(params, include_missing: false) # Filter undeclared parameters
        import_destination_params = d_params[:destinations].each{ |dest_params|
          dest_params[:visits]&.each{ |hash|
            convert_timewindows(hash)
            convert_deprecated_quantities(hash, current_customer.deliverable_units);
          }
        }
      end
      if params[:planning]
        if params[:planning][:vehicle_usage_set_id]
          params[:planning][:vehicle_usage_set] = current_customer.vehicle_usage_sets.find(params[:planning][:vehicle_usage_set_id])
        end
        params[:planning].delete(:vehicle_usage_set_id)
        if params[:planning][:zoning_ids] && !params[:planning][:zoning_ids].empty?
          params[:planning][:zonings] = current_customer.zonings.find(params[:planning][:zoning_ids])
        end
        params[:planning].delete(:zoning_ids)
      end
      import = if params[:destinations]
        # FIXME ImportJSON has its own conversion methods. It should be done at the API level
        ImportJson.new(importer: ImporterDestinations.new(current_customer, params[:planning]), replace: params[:replace], json: import_destination_params)
      elsif params[:remote]
        case params[:remote]
        when :tomtom then ImportTomtom.new(importer: ImporterDestinations.new(current_customer, params[:planning]), customer: current_customer, replace: params[:replace])
        end
      else
        ImportCsv.new(importer: ImporterDestinations.new(current_customer, params[:planning]), replace: params[:replace], file: params[:file])
      end

      if import && import.valid? && (destinations = import.import(true))
        case params[:remote]
        when :tomtom then status 202
        else present destinations, with: V01::Entities::Destination
        end
      else
        error!({error: import && import.errors.full_messages}, 422)
      end
    end

    desc 'Update destination.',
      detail: 'If want to force geocoding for a new address, you have to send empty lat/lng with new address.',
      nickname: 'updateDestination',
      success: V01::Status.success(:code_200, V01::Entities::Destination),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
      use :request_destination
    end
    put ':id' do
      raise Exceptions::JobInProgressError if current_customer.job_optimizer

      id = ParseIdsRefs.read(params[:id])
      destination = current_customer.destinations.where(id).first!
      destination.assign_attributes(destination_params)
      destination.save!
      destination.customer.save! if destination.customer
      present destination, with: V01::Entities::Destination
    end

    desc 'Delete destination.',
      nickname: 'deleteDestination',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
    end
    delete ':id' do
      raise Exceptions::JobInProgressError if current_customer.job_optimizer

      id = ParseIdsRefs.read(params[:id])
      current_customer.destinations.where(id).first!.destroy
      status 204
    end

    desc 'Delete multiple destinations.',
      nickname: 'deleteDestinations',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      optional :ids, type: Array[String], desc: 'Ids separated by comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3. If no Id is provided, all objects are deleted.', coerce_with: CoerceArrayString
    end
    delete do
      Destination.transaction do
        if params[:ids] && !params[:ids].empty?
          destinations = current_customer.destinations.select { |destination|
            params[:ids].any? { |s| ParseIdsRefs.match(s, destination) }
          }

          if current_customer.destinations_count == destinations.count
            current_customer.delete_all_destinations
          else
            destinations.each(&:destroy)
          end
        else
          current_customer.delete_all_destinations
        end
        status 204
      end
    end

    desc 'Geocode destination.',
      detail: 'Result of geocoding is not saved with this operation. You can use update operation to save the result of geocoding.',
      nickname: 'geocodeDestination',
      success: V01::Status.success(:code_200, V01::Entities::Destination),
      failure: V01::Status.failures
    params do
      use :params_from_entity, entity: V01::Entities::Destination.documentation.except(:id, :lat, :lng, :geocoding_accuracy, :geocoding_level, :visits)
    end
    patch 'geocode' do
      destination = current_customer.destinations.build(destination_params.except(:id, :visits_attributes))
      destination.geocode
      present destination, with: V01::Entities::Destination
    end

    desc 'Reverse geocoding.',
      detail: 'Result of reverse geocoding is not saved with this operation.',
      nickname: 'reverseGeocodingDestination',
      success: V01::Status.success(:code_200, V01::Entities::Destination),
      failure: V01::Status.failures
    params do
      use :params_from_entity, entity: V01::Entities::Destination.documentation.except(:id, :street, :postalcode, :city, :state, :country, :visits)
    end
    patch 'reverse' do
      destination = current_customer.destinations.build(destination_params.except(:id, :visits_attributes))
      destination.reverse_geocoding(params[:lat], params[:lng])
    end

    if Planner::Application.config.geocode_complete
      desc 'Auto completion on destination.',
        nickname: 'autocompleteDestination',
        success: V01::Status.success(:code_200, V01::Entities::Destination),
        failure: V01::Status.failures
      params do
        use :params_from_entity, entity: V01::Entities::Destination.documentation.except(:id, :visits)
      end
      patch 'geocode_complete' do
        p = destination_params.except(:id, :visits_attributes)
        store = current_customer.stores.select(&:position?).last
        address_list = Planner::Application.config.geocoder.complete(p[:street], p[:postalcode], p[:city], p[:state], p[:country] || current_customer.default_country, store.try(&:lat), store.try(&:lng))
        address_list = address_list.collect(&:compact)
        # TODO: returns results and priority location
        address_list
      end
    end
  end

  desc 'Fetch customer\'s destinations inside time/distance.',
    nickname: 'getDestinationsInsideTimeAndDistance',
    is_array: true,
    entity: V01::Entities::DestinationId
  params do
    requires :lat, type: Float, desc: 'Point latitude.'
    requires :lng, type: Float, desc: 'Point longitude.'
    optional :vehicle_usage_id, type: Integer, desc: 'Vehicle Usage uses in place of default router and speed multiplicator.'
    optional :distance, type: Integer, desc: 'Maximum distance in meter.'
    optional :time, type: Integer, desc: 'Maximum time in seconds.'
    at_least_one_of :time, :distance
  end
  get :destinations_by_time_and_distance do
    position = OpenStruct.new(lat: Float(params[:lat]), lng: Float(params[:lng]))
    vehicle_usage = VehicleUsage.joins(:vehicle_usage_set).where(vehicle_usage_sets: {customer_id: current_customer.id}, id: params[:vehicle_usage_id]).first
    if params.key?(:vehicle_usage_id) && vehicle_usage.nil?
      error! 'VehicleUsage not found', 404
    else
      destinations = current_customer.destinations_inside_time_distance(position, params[:distance], params[:time], vehicle_usage) || []
      present destinations, with: V01::Entities::DestinationId
    end
  end
end
