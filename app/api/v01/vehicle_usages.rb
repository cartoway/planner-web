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

class V01::VehicleUsages < Grape::API
  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def vehicle_usage_params
      p = ActionController::Parameters.new(params)
      p = p[:vehicle_usage] if p.key?(:vehicle_usage)
      p[:time_window_start] = p.delete(:open) if p[:open]
      p[:time_window_end] = p.delete(:close) if p[:close]
      p.permit(:name, :cost_distance, :cost_fixed, :cost_time, :time_window_start, :time_window_end, :store_start_id, :store_stop_id, :service_time_start, :service_time_end, :work_time, :rest_start, :rest_stop, :rest_duration, :store_duration, :store_rest_id, :active, tag_ids: [])
    end
  end

  resource :vehicle_usage_sets do
    params do
      requires :vehicle_usage_set_id, type: Integer
    end
    segment '/:vehicle_usage_set_id' do
      resource :vehicle_usages do
        desc 'Fetch customer\'s vehicle_usages.',
          nickname: 'getVehicleUsages',
          is_array: true,
          success: V01::Status.success(:code_200, V01::Entities::VehicleUsageWithVehicle),
          failure: V01::Status.failures(is_array: true, override: {code_404: 'VehicleUsageSet or VehicleUsage not found.'})
        params do
          optional :ids, type: Array[Integer], desc: 'Select returned vehicle_usages by id.', coerce_with: CoerceArrayInteger
        end
        get do
          vehicle_usage_set = current_customer.vehicle_usage_sets.where(id: params[:vehicle_usage_set_id]).first
          vehicle_usages = if vehicle_usage_set && params.key?(:ids)
            vehicle_usage_set.vehicle_usages.select{ |vehicle_usage| params[:ids].include?(vehicle_usage.id) }
          else
            vehicle_usage_set.vehicle_usages.load
          end
          if vehicle_usage_set && vehicle_usages
            present vehicle_usages, with: V01::Entities::VehicleUsageWithVehicle
          else
            error! V01::Status.code_response(:code_404, before: 'VehicleUsageSet or VehicleUsage'), 404
          end
        end

        desc 'Fetch vehicle_usage.',
          nickname: 'getVehicleUsage',
          success: V01::Status.success(:code_200, V01::Entities::VehicleUsageWithVehicle),
          failure: V01::Status.failures(override: {code_404: 'VehicleUsageSet or VehicleUsage not found.'})
        params do
          requires :id, type: Integer
        end
        get ':id' do
          vehicle_usage_set = current_customer.vehicle_usage_sets.where(id: params[:vehicle_usage_set_id]).first
          if vehicle_usage_set
            vehicle_usage = vehicle_usage_set.vehicle_usages.find{ |vehicle_usage| vehicle_usage.id == params[:id] }
            if vehicle_usage
              present vehicle_usage, with: V01::Entities::VehicleUsageWithVehicle
              return
            end
          end
          error! V01::Status.code_response(:code_404, before: 'VehicleUsageSet or VehicleUsage'), 404
        end

        desc 'Update vehicle_usage.',
          nickname: 'updateVehicleUsage',
          success: V01::Status.success(:code_200, V01::Entities::VehicleUsageWithVehicle),
          failure: V01::Status.failures(override: {code_404: 'VehicleUsageSet or VehicleUsage not found.' })
        params do
          requires :id, type: Integer
          use :request_vehicle_usage
        end
        put ':id' do
          params[:tag_ids] = filter_tag_ids_belong_to_customer(params[:tag_ids], current_customer) if params[:tag_ids]
          vehicle_usage_set = current_customer.vehicle_usage_sets.where(id: params[:vehicle_usage_set_id]).first
          if vehicle_usage_set
            vehicle_usage = vehicle_usage_set.vehicle_usages.find{ |vehicle_usage| vehicle_usage.id == params[:id] }
            if vehicle_usage
              vehicle_usage.update! vehicle_usage_params
              present vehicle_usage, with: V01::Entities::VehicleUsageWithVehicle
              return
            end
          end
          error! V01::Status.code_response(:code_404, before: 'VehicleUsageSet or VehicleUsage'), 404
        end
      end
    end
  end
end
