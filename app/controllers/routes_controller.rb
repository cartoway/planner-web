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
  before_action :authenticate_user!, except: [:mobile, :update_position, :driver_update]
  before_action :set_route, only: [:update, :modal]

  before_action :authenticate_driver!, only: [:mobile, :update_position, :driver_update]
  before_action :set_driver_route, only: [:mobile, :driver_update]

  load_and_authorize_resource

  include PlanningExport

  def mobile
    manage_planning
    @params = params
    @stops = @route.stops.includes_destinations_and_stores.only_active
    respond_to do |format|
      format.html {
        render 'routes/mobile',
        locals: {
          route: @route,
          enable_driver_move: ValueToBoolean.value_to_boolean(current_vehicle.customer.devices.dig(:deliver, :driver_move)),
          date: @route.planning.date,
          is_expired: @route.is_expired?,
          stop_visit_custom_attributes: current_vehicle.customer.custom_attributes.for_stop_visit,
          stop_store_custom_attributes: current_vehicle.customer.custom_attributes.for_stop_store,
          start_route_data_custom_attributes: current_vehicle.customer.custom_attributes.for_route.for_related_field('start_route_data'),
          stop_route_data_custom_attributes: current_vehicle.customer.custom_attributes.for_route.for_related_field('stop_route_data'),
          customer: current_vehicle.customer
        },
        layout: 'mobile'
      }
    end
  end

  def modal
    case params[:modal]
    when 'sms_drivers'
      respond_to do |format|
        format.js { render partial: 'plannings/send_sms_drivers', locals: { planning: @route.planning, routes: [@route] } }
      end
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
          if Planner::Application.config.delayed_job_use
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
        permitted_export_params = export_params
        @customer = current_user.customer
        @custom_columns = @customer.advanced_options&.dig('import', 'destinations', 'spreadsheetColumnsDef')
        @columns = permitted_export_params[:columns]&.split('|') || export_columns
        current_user.save_export_settings(@columns, permitted_export_params[:skips]&.split('|'), permitted_export_params[:stops]&.split('|'), 'excel')
        send_data render_to_string.encode(I18n.t('encoding'), invalid: :replace, undef: :replace, replace: ''),
          type: 'text/csv',
          filename: filename + '.csv'
      end
      format.csv do
        permitted_export_params = export_params
        @customer = current_user.customer
        @custom_columns = @customer.advanced_options&.dig('import', 'destinations', 'spreadsheetColumnsDef')
        @columns = permitted_export_params[:columns]&.split('|') || export_columns
        current_user.save_export_settings(@columns, permitted_export_params[:skips]&.split('|'), permitted_export_params[:stops]&.split('|'), 'csv')
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

  def driver_update
    respond_to do |format|
      route_params = route_driver_params
      # Force nested route_data ids to the current route's records (never trust client-supplied id)
      if route_params[:start_route_data_attributes].present?
        route_params[:start_route_data_attributes] = route_params[:start_route_data_attributes].to_h.merge(id: @route.start_route_data.id)
      end
      if route_params[:stop_route_data_attributes].present?
        route_params[:stop_route_data_attributes] = route_params[:stop_route_data_attributes].to_h.merge(id: @route.stop_route_data.id)
      end
      if @route.update(route_params)
        format.json do
          render json: { success: true }
        end
        format.html do
          if request.xhr?
            head :ok
          else
            head :no_content
          end
        end
      else
        format.json do
          flash.now[:alert] = I18n.t('routes.error_messages.update.failure')
          render json: { error: I18n.t('routes.error_messages.update.failure') }.to_json,
                 status: :unprocessable_entity
        end
        format.html do
          head :unprocessable_entity
        end
      end
    end
  end

  def update_position
    @customer = current_vehicle.customer
    if params['latitude'] && params['longitude'] && params['latitude'].is_a?(Float) && params['longitude'].is_a?(Float)
      Planner::Application.config.devices.to_h.each{ |key, device|
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

  def manage_planning
    @manage_planning = ApiWeb::V01::PlanningsController.manage
    @callback_button = true
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_route
    @route = Route.includes_vehicle_usages.for_customer_id(current_user.customer_id).find(params[:id] || params[:route_id])
  end

  def set_driver_route
    @route = Route.includes_vehicle_usages.find(params[:id])

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

  def route_driver_params
    permitted = params.require(:route).permit(
      :status,
      start_route_data_attributes: [:status],
      stop_route_data_attributes: [:status],
      custom_attributes: RecursiveParamsHelper.permit_recursive(params['route']['custom_attributes'])
    )

    merge_route_custom_attributes!(permitted) if permitted[:custom_attributes].present?

    permitted
  end

  # Merges incoming custom_attributes using composite keys (related_field:name).
  # Converts nested or flat incoming params to flat hash with composite keys.
  def merge_route_custom_attributes!(permitted)
    merged = (@route.custom_attributes || {}).dup
    nested_keys = %w[start_route_data stop_route_data]
    incoming = permitted[:custom_attributes]

    # Convert nested structure (from form) to composite keys
    if incoming.keys.any? { |k| nested_keys.include?(k.to_s) }
      incoming.each do |key, value|
        key_s = key.to_s
        if nested_keys.include?(key_s) && value.is_a?(Hash)
          value.each { |name, val| merged["#{key_s}:#{name}"] = val }
        elsif !nested_keys.include?(key_s)
          merged[key_s] = value
        end
      end
    else
      # Flat: infer related_field from route_data_attributes context when keys are not already composite
      related_field = if permitted[:start_route_data_attributes].present? && permitted[:stop_route_data_attributes].blank?
        'start_route_data'
      elsif permitted[:stop_route_data_attributes].present? && permitted[:start_route_data_attributes].blank?
        'stop_route_data'
      end

      incoming.each do |k, v|
        key_s = k.to_s
        # Keys from form may already be composite (e.g. "start_route_data:Kilométrage"), do not double-prefix
        storage_key = if related_field && !key_s.include?(':')
          "#{related_field}:#{key_s}"
        else
          key_s
        end
        merged[storage_key] = v
      end
    end

    permitted[:custom_attributes] = merged
  end

  def export_params
    params.permit(:columns, :skips, :stops)
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
      :departure,
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
      :out_of_max_reload,
      :out_of_relation,
      :out_of_skill,
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
      :destination_duration,
      :duration,
      :time_window_start_1,
      :time_window_end_1,
      :time_window_start_2,
      :time_window_end_2,
      :priority,
      :revenue,
      :force_position,
      :tags_visit
    ] + (@route.planning.customer.enable_orders ?
      [:orders] :
      @route.planning.customer.deliverable_units.flat_map{ |du|
        [
          ('pickup' + (du.label ? "[#{du.label}]" : "#{du.id}")).to_sym,
          ('delivery' + (du.label ? "[#{du.label}]" : "#{du.id}")).to_sym
        ]
      }) +
      (@customer || @planning.customer).custom_attributes.for_visit.map{ |ca|
        "custom_attributes_visit[#{ca.name}]".to_sym
      } + (@customer || @planning.customer).custom_attributes.for_export_stops_unique_by_name.map{ |ca|
       "custom_attributes_stop[#{ca.name}]".to_sym
      }
  end
end
