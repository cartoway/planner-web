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

class V01::Stores < Grape::API
  content_type :geojson, 'application/vnd.geo+json'

  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def store_params
      p = ActionController::Parameters.new(params)
      p = p[:store] if p.key?(:store)
      p.permit(:ref, :name, :street, :postalcode, :city, :state, :country, :lat, :lng, :geocoding_accuracy, :geocoding_level, :color, :icon, :icon_size)
    end
  end

  resource :stores do
    desc 'Fetch customer\'s stores. At least one store exists per customer.',
      nickname: 'getStores',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::Store),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :ids, type: Array[String], desc: 'Select returned stores by id separated with comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
    end
    get do
      stores = if params.key?(:ids)
                 current_customer.stores.select {|store|
                   params[:ids].any? {|s| ParseIdsRefs.match(s, store)}
                 }
               else
                 current_customer.stores.load
               end

      if env['api.format'] == :geojson
        '{"type":"FeatureCollection","features":[' + stores.map { |store|
          if store.position?
            feat = {
                type: 'Feature',
                geometry: {
                    type: 'Point',
                    coordinates: [store.lng.round(6), store.lat.round(6)]
                },
                properties: {
                    store_id: store.id,
                    color: store.color,
                    icon: store.icon,
                    icon_size: store.icon_size
                }
            }.to_json
          end
        }.compact.join(',') + ']}'
      else
        present stores, with: V01::Entities::Store
      end
    end

    desc 'Fetch store.',
      nickname: 'getStore',
      success: V01::Status.success(:code_200, V01::Entities::Store),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
    end
    get ':id' do
      id = ParseIdsRefs.read(params[:id])
      present current_customer.stores.where(id).first!, with: V01::Entities::Store
    end

    desc 'Create store.',
      detail: '(Note a default store is already automatically created with a customer.)',
      nickname: 'createStore',
      success: V01::Status.success(:code_201, V01::Entities::Store),
      failure: V01::Status.failures
    params do
      use(:request_store, require_store_name: true)
      optional :geocoding_accuracy, type: Float, documentation: { desc: 'Must be inside 0..1 range.' }
    end
    post do
      store = current_customer.stores.build(store_params)
      current_customer.save!
      present store, with: V01::Entities::Store
    end

    desc 'Import stores by upload a CSV file or by JSON.',
      nickname: 'importStores',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::Store),
      failure: V01::Status.failures(is_array: true, add: [:code_422])
    params do
      optional :stores, type: Array, documentation: { param_type: 'body' } do
        optional :id, type: String, desc: SharedParams::ID_DESC
        use :request_store
      end
      optional :file, type: CSVFile, documentation: { desc: 'CSV file' }
      mutually_exclusive :stores, :file
    end
    put do
      import = if params[:stores]
                 ImportJson.new(importer: ImporterStores.new(current_customer), replace: params[:replace], json: params[:stores])
               else
                 ImportCsv.new(importer: ImporterStores.new(current_customer), replace: params[:replace], file: params[:file])
               end

      if import && import.valid? && (stores = import.import(true))
        present stores, with: V01::Entities::Store
      else
        error!({error: import.errors.full_messages}, 422)
      end
    end

    desc 'Update store.',
      detail: 'If want to force geocoding for a new address, you have to send empty lat/lng with new address.',
      nickname: 'updateStore',
      success: V01::Status.success(:code_200, V01::Entities::Store),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
      use :request_store
    end
    put ':id' do
      id = ParseIdsRefs.read(params[:id])
      store = current_customer.stores.where(id).first!
      store.assign_attributes(store_params)
      store.save!
      store.customer.save! if store.customer
      present store, with: V01::Entities::Store
    end

    desc 'Delete store.',
      detail: 'At least one remaining store is required after deletion.',
      nickname: 'deleteStore',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: String, desc: SharedParams::ID_DESC
    end
    delete ':id' do
      id = ParseIdsRefs.read(params[:id])
      current_customer.stores.where(id).first!.destroy!
      status 204
    end

    desc 'Delete multiple stores.',
      detail: 'At least one remaining store is required after deletion.',
      nickname: 'deleteStores',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :ids, type: Array[String], desc: 'Ids separated by comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
    end
    delete do
      Store.transaction do
        current_customer.stores.select{ |store|
          params[:ids].any?{ |s| ParseIdsRefs.match(s, store) }
        }.each(&:destroy)
      end
      status 204
    end

    desc 'Geocode store.',
      detail: 'Result of geocoding is not saved with this operation. You can use update operation to save the result of geocoding.',
      nickname: 'geocodeStore',
      success: V01::Status.success(:code_200, V01::Entities::Store),
      failure: V01::Status.failures
    params do
      use :params_from_entity, entity: V01::Entities::Store.documentation.except(:id, :lat, :lng, :geocoding_accuracy, :geocoding_level)
    end
    patch 'geocode' do
      store = current_customer.stores.build(store_params)
      store.geocode
      present store, with: V01::Entities::Store
    end

    if Mapotempo::Application.config.geocode_complete
      desc 'Auto completion on store.',
        nickname: 'autocompleteStore',
        is_array: true,
        success: V01::Status.success(:code_200),
        failure: V01::Status.failures(is_array: true)
      params do
        use :params_from_entity, entity: V01::Entities::Store.documentation.except(:id)
      end
      patch 'geocode_complete' do
        p = store_params
        store = current_customer.stores.select(&:position?).last
        address_list = Mapotempo::Application.config.geocoder.complete(p[:street], p[:postalcode], p[:city], p[:state], p[:country] || current_customer.default_country, store.try(&:lat), store.try(&:lng))
        address_list = address_list.collect(&:compact)
        # TODO: returns results and priority location
        address_list
      end
    end

    desc 'Reverse geocoding.',
      detail: 'Result of reverse geocoding is not saved with this operation.',
      nickname: 'reverseGeocodingStore',
      success: V01::Status.success(:code_200, V01::Entities::Store),
      failure: V01::Status.failures
    params do
      use :params_from_entity, entity: V01::Entities::Store.documentation.except(:id, :color, :name, :icon, :icon_size, :street, :postalcode, :city, :state, :country)
    end
    patch 'reverse' do
      store = current_customer.stores.build(store_params.except(:id, :color, :name, :icon, :icon_size))
      store.reverse_geocoding(params[:lat], params[:lng])
    end
  end



  desc 'Import synchronously vehicle, vehicle_usage and store (with only one vehicle_usage_set present) by upload a CSV file or by JSON.',
    nickname: 'importVehicleStores',
    params: V01::Entities::VehicleStoresImport.documentation,
    is_array: true,
    entity: V01::Entities::VehicleStore
  put :import_vehicle_stores do

    import = if params[:stores]
      ImportJson.new(importer: ImporterVehicleStores.new(current_customer), replace: params[:replace], json: params[:stores])
    else
      ImportCsv.new(importer: ImporterVehicleStores.new(current_customer), replace: params[:replace], file: params[:file])
    end

    if import && import.valid? && (stores = import.import(true))
      present stores, with: V01::Entities::Store
    else
      error!({error: import.errors.full_messages}, 422)
    end
  end

  desc 'Fetch customer\'s stores by distance.',
    nickname: 'getStoresByDistance',
    is_array: true,
    entity: V01::Entities::Store
  params do
    requires :lat, type: Float, desc: 'Point latitude.'
    requires :lng, type: Float, desc: 'Point longitude.'
    requires :n, type: Integer, desc: 'Number of results.'
    optional :vehicle_usage_id, type: Integer, desc: 'Vehicle Usage uses in place of default router and speed multiplicator.'
  end
  get :stores_by_distance do
    position = OpenStruct.new(lat: Float(params[:lat]), lng: Float(params[:lng]))
    vehicle_usage = VehicleUsage.joins(:vehicle_usage_set).where(vehicle_usage_sets: {customer_id: current_customer.id}, id: params[:vehicle_usage_id]).first
    if params.key?(:vehicle_usage_id) && vehicle_usage.nil?
      error! 'VehicleUsage not found', 404
    else
      stores = current_customer.stores_by_distance(position, Integer(params[:n]), vehicle_usage)
      present stores, with: V01::Entities::Store
    end
  end
end
