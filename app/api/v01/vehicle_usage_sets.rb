# Copyright © Mapotempo, 2015
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

class V01::VehicleUsageSets < Grape::API
  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def vehicle_usage_set_params
      p = ActionController::Parameters.new(params)
      p = p[:vehicle_usage_set] if p.key?(:vehicle_usage_set)
      p[:time_window_start] = p.delete(:open) if p[:open]
      p[:time_window_end] = p.delete(:close) if p[:close]
      p = p.permit(:name, :time_window_start, :time_window_end, :store_start_id, :store_stop_id, :service_time_start, :service_time_end, :work_time, :rest_start, :rest_stop, :rest_duration, :store_rest_id, :max_distance, :max_ride_distance, :max_ride_duration)
      p
    end
  end

  resource :vehicle_usage_sets do
    desc 'Fetch customer\'s vehicle_usage_sets. At least one vehicle_usage_set exists per customer.',
      nickname: 'getVehicleUsageSets',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::VehicleUsageSet),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :ids, type: Array[Integer], desc: 'Select returned vehicle_usage_sets by id.', coerce_with: CoerceArrayInteger
    end
    get do
      vehicle_usage_sets = if params.key?(:ids)
        current_customer.vehicle_usage_sets.select{ |vehicle_usage_set| params[:ids].include?(vehicle_usage_set.id) }
      else
        current_customer.vehicle_usage_sets.load
      end
      present vehicle_usage_sets, with: V01::Entities::VehicleUsageSet
    end

    desc 'Fetch vehicle_usage_set.',
      nickname: 'getVehicleUsageSet',
      success: V01::Status.success(:code_200, V01::Entities::VehicleUsageSet),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    get ':id' do
      present current_customer.vehicle_usage_sets.find(params[:id]), with: V01::Entities::VehicleUsageSet
    end

    desc 'Create vehicle_usage_set.',
      detail: "(Note a vehicle_usage_set is already automatically created with a customer.) Only available if \"multi usage set\" option is active for current customer.
        For instance, if customer needs to use its vehicle 2 times per day (morning and evening), he needs 2 VehicleUsageSet called \"Morning\" and \"Evening\". A VehicleUsage per Vehicle is automatically created. The new VehicleUsageSet allows to define new default values for VehicleUsage.",
      nickname: 'createVehicleUsageSet',
      success: V01::Status.success(:code_201, V01::Entities::VehicleUsageSet),
      failure: V01::Status.failures
    params do
      use :params_from_entity, entity: V01::Entities::VehicleUsageSet.documentation.except(
          :id,
          :max_ride_duration,
          :time_window_start,
          :time_window_end,
          :service_time_start,
          :service_time_end,
          :work_time,
          :rest_start,
          :rest_stop,
          :rest_duration,
          :open,
          :close
      ).deep_merge(
        name: { required: true },
        store_start_id: { required: true },
        store_stop_id: { required: true }
      )

      requires :time_window_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      requires :time_window_end, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :service_time_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :service_time_end, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :work_time, type: Integer, documentation: { type: 'string', desc: 'Work time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :rest_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :rest_stop, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :rest_duration, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :max_distance, type: Integer, documentation: { type: 'integer', desc: 'Maximum achievable distance in meters' }
      optional :max_ride_distance, type: Integer, documentation: { desc: 'Maximum riding distance between two stops within a route in meters' }
      optional :max_ride_duration, type: Integer, documentation: { desc: 'Maximum riding time between two stops within a route (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    end
    post do
      vehicle_usage_set = current_customer.vehicle_usage_sets.build(vehicle_usage_set_params)
      vehicle_usage_set.save!
      present vehicle_usage_set, with: V01::Entities::VehicleUsageSet
    end

    desc 'Update vehicle_usage_set.',
      nickname: 'updateVehicleUsageSet',
      success: V01::Status.success(:code_200, V01::Entities::VehicleUsageSet),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
      use :params_from_entity, entity: V01::Entities::VehicleUsageSet.documentation.except(
          :id,
          :max_ride_duration,
          :time_window_start,
          :time_window_end,
          :service_time_start,
          :service_time_end,
          :work_time,
          :rest_start,
          :rest_stop,
          :rest_duration,
          :open,
          :close)

      optional :time_window_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :time_window_end, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :service_time_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :service_time_end, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :work_time, type: Integer, documentation: { type: 'string', desc: 'Work time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :rest_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :rest_stop, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :rest_duration, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      optional :max_distance, type: Integer, documentation: { type: 'integer', desc: 'Maximum achievable distance in meters' }
      optional :max_ride_distance, type: Integer, documentation: { desc: 'Maximum riding distance between two stops within a route in meters' }
      optional :max_ride_duration, type: Integer, documentation: { desc: 'Maximum riding time between two stops within a route (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }

      # Deprecated fields
      optional :open, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      mutually_exclusive :time_window_start, :open
      optional :close, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
      mutually_exclusive :time_window_end, :close
    end
    put ':id' do
      vehicle_usage_set = current_customer.vehicle_usage_sets.find(params[:id])
      vehicle_usage_set.update! vehicle_usage_set_params
      present vehicle_usage_set, with: V01::Entities::VehicleUsageSet
    end

    desc 'Delete vehicle_usage_set.',
      nickname: 'deleteVehicleUsageSet',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer
    end
    delete ':id' do
      current_customer.vehicle_usage_sets.find(params[:id]).destroy
      status 204
    end

    desc 'Delete multiple vehicle_usage_sets.',
      nickname: 'deleteVehicleUsageSets',
      success: V01::Status.success(:code_204),
      failure: V01::Status.failures
    params do
      requires :ids, type: Array[Integer], coerce_with: CoerceArrayInteger
    end
    delete do
      VehicleUsageSet.transaction do
        current_customer.vehicle_usage_sets.select{ |vehicle_usage_set| params[:ids].include?(vehicle_usage_set.id) }.each(&:destroy)
      end
      status 204
    end

    desc 'Import vehicle usage set by upload a CSV file or by JSON.',
      nickname: 'importVehicleUsageSets',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::VehicleUsageSet),
      failure: V01::Status.failures(is_array: true, add: [:code_422])
    params do
      use :params_from_entity, entity: V01::Entities::VehicleUsageSetsImport.documentation
    end
    put do
      import = if params[:vehicle_usage_sets]
                 ImportJson.new(importer: ImporterVehicleUsageSets.new(current_customer), replace_vehicles: params[:replace_vehicles], json: params[:vehicle_usage_sets])
               else
                 ImportCsv.new(importer: ImporterVehicleUsageSets.new(current_customer), replace_vehicles: params[:replace_vehicles], file: params[:file])
               end

      if import && import.valid? && (vehicles_usages_with_conf = import.import)
        present vehicles_usages_with_conf, with: V01::Entities::Vehicle
      else
        error!({error: import.errors.full_messages}, 422)
      end
    end
  end
end
