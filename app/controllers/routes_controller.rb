# Copyright © Mapotempo, 2013-2016
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

require 'csv'
require 'value_to_boolean'
require 'zip'

class RoutesController < ApplicationController
  before_action :authenticate_user!, except: [:mobile, :update_position]
  before_action :set_route, only: [:update]

  before_action :authenticate_driver!, only: [:mobile, :update_position]
  before_action :set_driver_route, only: [:mobile]

  load_and_authorize_resource

  include PlanningExport

  def mobile
    @params = params
    @stops = @route.stops.only_active_stop_visits
    respond_to do |format|
      format.html {
        render 'routes/mobile',
        locals: {
          route: @route,
          date: @route.planning.date,
          is_expired: @route.is_expired?,
          custom_attributes: current_vehicle.customer.custom_attributes.select{ |c_u| c_u.object_class == 'stop' }
        },
        layout: 'mobile'
      }
    end
  end

  def show
    @params = params
    respond_to do |format|
      format.html
      format.gpx do
        @gpx_track = !!params['track']
        response.headers['Content-Disposition'] = 'attachment; filename="' + filename + '.gpx"'
      end
      format.kml do
        response.headers['Content-Disposition'] = 'attachment; filename="' + filename + '.kml"'
        render 'routes/show', locals: { route: @route }
      end
      format.kmz do
        if params[:email]
          vehicle = @route.vehicle_usage.vehicle
          content = kmz_string_io(route: @route).string
          if Mapotempo::Application.config.delayed_job_use
            RouteMailer.delay.send_kmz_route current_user, I18n.locale, vehicle, @route, filename + '.kmz', content
          else
            RouteMailer.send_kmz_route(current_user, I18n.locale, vehicle, @route, filename + '.kmz', content).deliver_now
          end
          head :no_content
        else
          send_data kmz_string_io(route: @route).string,
            type: 'application/vnd.google-earth.kmz',
            filename: filename + '.kmz'
        end
      end
      format.excel do
        @customer = current_user.customer
        @custom_columns = @customer.advanced_options&.dig('import', 'destinations', 'spreadsheetColumnsDef')
        @columns = (@params[:columns] && @params[:columns].split('|')) || export_columns
        send_data Iconv.iconv("#{I18n.t('encoding')}//translit//ignore", 'utf-8', render_to_string).join(''),
          type: 'text/csv',
          filename: filename + '.csv'
      end
      format.csv do
        @customer = current_user.customer
        @custom_columns = @customer.advanced_options&.dig('import', 'destinations', 'spreadsheetColumnsDef')
        @columns = (@params[:columns] && @params[:columns].split('|')) || export_columns
        response.headers['Content-Disposition'] = 'attachment; filename="' + filename + '.csv"'
      end
    end
  end

  def update
    respond_to do |format|
      if @route.update(route_params)
        format.html { redirect_to @route, notice: t('activerecord.successful.messages.updated', model: @route.class.model_name.human) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def update_position
    @customer = current_vehicle.customer
    if params['latitude'] && params['longitude'] && params['latitude'].is_a?(Float) && params['longitude'].is_a?(Float)
      Mapotempo::Application.config.devices.to_h.each{ |key, device|
        next if @customer.device.enabled_definitions.exclude?(key)

        service = Object.const_get(device.class.name + 'Service').new({customer: @customer})
        service.cache_position(@route.vehicle_usage.vehicle, params) if service.respond_to?(:cache_position)
      }
      if request.xhr?
        head :ok
      else
        head :no_content
      end
    else
      head :bad_request
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_route
    @route = Route.for_customer_id(current_user.customer_id).find params[:id]
  end

  def set_driver_route
    @route = Route.find(params[:id])

    if @route.vehicle_usage.vehicle.id != current_vehicle.id
      head :not_found
    else
      @route
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def route_params
    params.require(:route).permit(:hidden, :locked, :ref, :color)
  end

  def filename
    format_filename(export_filename(@route.planning, @route.ref || @route.vehicle_usage.vehicle.name))
  end

  def export_columns
    [
      :route,
      :vehicle,
      :order,
      :stop_type,
      :active,
      :wait_time,
      :time,
      :distance,
      :drive_time,
      :out_of_window,
      :out_of_capacity,
      :out_of_drive_time,
      :out_of_force_position,
      :out_of_work_time,
      :out_of_max_distance,
      :out_of_max_ride_distance,
      :out_of_max_ride_duration,
      :out_of_relation,
      :status,
      :status_updated_at,
      :eta,

      :ref,
      :name,
      :street,
      :detail,
      :postalcode,
      :city,
      :country,
      :lat,
      :lng,
      :comment,
      :phone_number,
      :tags,

      :ref_visit,
      :duration,
      :time_window_start_1,
      :time_window_end_1,
      :time_window_start_2,
      :time_window_end_2,
      :priority,
      :force_position,
      :tags_visit
    ] + (@route.planning.customer.enable_orders ?
      [:orders] :
      @route.planning.customer.deliverable_units.map{ |du|
        ('quantity' + (du.label ? "[#{du.label}]" : "#{du.id}")).to_sym
      })
  end
end
