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
class VehicleUsagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_vehicle_usage, only: [:edit, :update, :toggle]

  load_and_authorize_resource

  include LinkBack

  def edit
  end

  def update
    respond_to do |format|
      p = vehicle_usage_params
      time_with_day_params(params, p, [:time_window_start, :time_window_end, :max_ride_duration], [:rest_start, :rest_stop, :work_time])
      @vehicle_usage.assign_attributes(p)

      if @vehicle_usage.save
        format.html { redirect_to link_back || edit_vehicle_usage_path(@vehicle_usage), notice: t('activerecord.successful.messages.updated', model: @vehicle_usage.class.model_name.human) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def toggle
    if @vehicle_usage.update active: !@vehicle_usage.active?
      redirect_to vehicle_usage_sets_path + "#collapseUsageSet#{@vehicle_usage.vehicle_usage_set_id}", notice: t('.success')
    else
      render action: :edit
    end
  end

  private

  def time_with_day_params(params, local_params, times_with_default, times)
    # Convert each time field into integer from hour and day value
    times_with_default.each do |time|
      if !params[:vehicle_usage]["#{time}_day".to_sym].to_s.empty? && !local_params[time].to_s.empty?
        local_params[time] = ChronicDuration.parse("#{params[:vehicle_usage]["#{time}_day".to_sym]} days and #{local_params[time].tr(':', 'h')}min", keep_zero: true)
      elsif !params[:vehicle_usage]["#{time}_day".to_sym].to_s.empty? && local_params[time].to_s.empty?
        # Use default value if only input day is given
        default_time_value = @vehicle_usage.send("default_#{time}_time")
        if default_time_value && !default_time_value.empty?
          local_params[time] = ChronicDuration.parse("#{params[:vehicle_usage]["#{time}_day".to_sym]} days and #{default_time_value.tr(':', 'h')}min", keep_zero: true)
        end
      end
    end

    times.each do |time|
      if !params[:vehicle_usage]["#{time}_day".to_sym].to_s.empty? && !local_params[time].to_s.empty?
        local_params[time] = ChronicDuration.parse("#{params[:vehicle_usage]["#{time}_day".to_sym]} days and #{local_params[time].tr(':', 'h')}min", keep_zero: true)
      end
    end
  end

  def set_vehicle_usage
    @vehicle_usage = VehicleUsage.for_customer_id(current_user.customer_id).find params[:id]
  end

  def vehicle_usage_params
    if params.dig('vehicle_usage', 'vehicle', 'router') # Unsafe navigation
      params[:vehicle_usage][:vehicle][:router_id], params[:vehicle_usage][:vehicle][:router_dimension] = params[:vehicle_usage][:vehicle][:router].split('_')
    end
    if params.dig('vehicle_usage', 'vehicle', 'router_options') # Unsafe navigation
      parse_router_options(params.dig('vehicle_usage', 'vehicle'))
    end
    parameters = params.require(:vehicle_usage).permit(
      :time_window_start,
      :time_window_end,
      :store_start_id,
      :store_stop_id,
      :rest_start,
      :rest_stop,
      :rest_duration,
      :store_rest_id,
      :service_time_start,
      :service_time_end,
      :work_time,
      tag_ids: [],
      vehicle: [
        :contact_email,
        :phone_number,
        :ref,
        :name,
        :emission,
        :consumption,
        :color,
        :router_id,
        :router_dimension,
        :speed_multiplier,
        :max_distance,
        :max_ride_distance,
        :max_ride_duration,
        capacities: current_user.customer.deliverable_units.map { |du| du.id.to_s },
        router_options: [
          :time,
          :distance,
          :isochrone,
          :isodistance,
          :traffic,
          :avoid_zones,
          :track,
          :motorway,
          :toll,
          :trailers,
          :weight,
          :weight_per_axle,
          :height,
          :width,
          :length,
          :hazardous_goods,
          :max_walk_distance,
          :approach,
          :snap,
          :strict_restriction,
          :low_emission_zone
        ],
        devices: permit_devices,
        tag_ids: []
      ])
    if parameters.key?(:vehicle)
      parameters[:vehicle_attributes] = parameters[:vehicle]
      parameters[:vehicle_attributes][:devices] = {} unless parameters[:vehicle_attributes].key?(:devices)
      parameters[:vehicle_attributes][:max_distance] = DistanceUnits.distance_to_meters(parameters[:vehicle_attributes][:max_distance], @current_user.prefered_unit) if parameters[:vehicle_attributes].key?(:max_distance)
      parameters[:vehicle_attributes][:max_ride_distance] = DistanceUnits.distance_to_meters(parameters[:vehicle_attributes][:max_ride_distance], @current_user.prefered_unit) if parameters[:vehicle_attributes].key?(:max_ride_distance)
      parameters.except(:vehicle)
    else
      parameters
    end
  end

  def permit_devices
    permit = []
    permit_multiples = []
    Mapotempo::Application.config.devices.to_h.each{ |_device_name, device_object|
      if device_object.respond_to?('definition')
        device_definition = device_object.definition
        if device_definition.key?(:forms) && device_definition[:forms].key?(:vehicle)
          device_definition[:forms][:vehicle].keys.each{ |key|
            if key.to_s[-1] == 's'
              permit_multiples << {key => []}
            else
              permit << key
            end
          }
        end
      end
    }
    permit + permit_multiples
  end
end
