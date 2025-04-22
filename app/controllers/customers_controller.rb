# frozen_string_literal: true

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
class CustomersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer, only: %i[edit update delete_vehicle external_callback]

  load_and_authorize_resource

  include V01::Devices::DeviceHelpers

  def index
    respond_to do |format|
      format.html do
        @customers = current_user.reseller.customers.includes_deps
      end
      format.json do
        @customers = current_user.reseller.customers.includes_stores
      end
    end
  end

  def new
    @customer = current_user.reseller.customers.build
  end

  def edit; end

  def create
    @customer = current_user.reseller.customers.build(customer_params)
    respond_to do |format|
      if @customer.save
        format.html { redirect_to edit_customer_path(@customer), notice: t('activerecord.successful.messages.created', model: @customer.class.model_name.human) }
      else
        format.html { render action: 'new' }
      end
    end
  end

  def update
    @customer.assign_attributes(customer_params)
    respond_to do |format|
      if @customer.save
        format.html { redirect_to edit_customer_path(@customer), notice: t('activerecord.successful.messages.updated', model: @customer.class.model_name.human) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path, notice: t('.success')
  end

  def destroy_multiple
    current_user.reseller.customers.find(params[:customers].keys).each(&:destroy) if params[:customers]
    redirect_to customers_path, notice: t('.success')
  end

  def delete_vehicle
    if current_user.admin? || !Planner::Application.config.manage_vehicles_only_admin
      @customer.vehicles.find(params[:vehicle_id]).destroy
    end
    redirect_to [:edit, @customer], notice: t('.success')
  end

  def duplicate
    @customer.duplicate.save! validate: Planner::Application.config.validate_during_duplication
    redirect_to [:customers], notice: t('.success')
  end

  def export
    export = ImportExportCustomer.export(@customer)
    send_data export, filename: "customer_#{@customer.name}_#{@customer.id}.dump"
  end

  def import
    @customer = current_user.reseller.customers.build
  end

  def upload_dump
    uploaded_io = customer_params[:uploaded_file]
    if uploaded_io.nil?
      @customer = current_user.reseller.customers.build
      flash.now[:alert] = I18n.t('customers.upload_dump.file_empty')
      render action: :import
    else
      file_path = Rails.root.join('public', 'uploads', uploaded_io.original_filename)
      File.open(file_path, 'wb'){ |file| file.write(uploaded_io.read) }

      string_customer = File.open(file_path, 'rb')
      options = {profile_id: customer_params[:profile_id], router_id: customer_params[:router_id], layer_id: customer_params[:layer_id]}

      File.delete(file_path)

      customer = ImportExportCustomer.import(string_customer, options)

      redirect_to [:customers], notice: t('.success', customer_name: customer.name)
    end
  end

  def external_callback
    if current_user.customer.enable_external_callback
      external_url = current_user.customer.external_callback_url
      @planning = current_user.customer.plannings.find(params[:planning_id]) if params[:planning_id]
      @route = @planning.routes.find(params[:route_id]) if @planning && params[:route_id]
      @plannings = current_user.customer.plannings.where(id: params[:planning_ids].split(',')) if params[:planning_ids]

      begin
        external_url =
          external_url.gsub('{PLANNING_ID}', @planning&.id&.to_s || 'null')
                      .gsub('{PLANNING_REF}', @planning&.ref || 'null')
                      .gsub('{PLANNING_IDS}', @plannings&.map(&:id)&.join(',') || 'null')
                      .gsub('{ROUTE_ID}', @route&.id&.to_s || 'null')
                      .gsub('{ROUTE_REF}', @route&.ref || 'null')
                      .gsub('{API_KEY}', current_user.api_key)
                      .gsub('{CUSTOMER_ID}', current_user.customer_id.to_s)

        if ExternalCallbackService.new(external_url).call
          render json: { status: :ok }
        else
          render json: { status: :unprocessable_entity, error: I18n.t('services.external_callback.fail') }, status: :unprocessable_entity
        end
      rescue ExternalCallbackService::ExternalCallbackError => e
        render json: { status: :unprocessable_entity, error: e.message }, status: :unprocessable_entity
      end
    else
      render json: {}, status: :forbidden
    end
  end

  private

  def set_customer
    @customer = if current_user.admin?
                  current_user.reseller.customers.find(params[:id])
                else
                  raise(ActiveRecord::RecordNotFound) if params[:id].to_s != current_user.customer.id.to_s
                  current_user.customer
                end
  end

  def customer_params
    unsafe_params = params.to_unsafe_h
    if unsafe_params[:customer][:router]
      unsafe_params[:customer][:router_id], unsafe_params[:customer][:router_dimension] = unsafe_params[:customer][:router].split('_')
    end
    parse_router_options(unsafe_params[:customer]) if unsafe_params[:customer][:router_options]
    if unsafe_params[:customer][:end_subscription] && !unsafe_params[:customer][:end_subscription].blank?
      unsafe_params[:customer][:end_subscription] = Date.strptime(unsafe_params[:customer][:end_subscription], I18n.t('time.formats.datepicker')).strftime(ACTIVE_RECORD_DATE_MASK)
    end
    # From customer form all keys are not present: need merge
    devices_params = unsafe_params.dig('customer', 'devices')
    devices_params = @customer[:devices].deep_stringify_keys.deep_merge(devices_params || {}) if @customer&.devices&.any?
    devices_params ||= {}
    unsafe_params['customer']['devices'] = devices_params

    p = ActionController::Parameters.new(unsafe_params)
    if current_user.admin?
      parameters = p.require(:customer).permit(
        :ref,
        :name,
        :description,
        :end_subscription,
        :test,
        :visit_duration,
        :default_country,
        :with_state,
        :max_vehicles,
        :max_plannings,
        :max_zonings,
        :max_destinations,
        :max_vehicle_usage_sets,
        :enable_orders,
        :enable_references,
        :enable_global_optimization,
        :enable_vehicle_position,
        :enable_stop_status,
        :enable_sms,
        :enable_optimization_soft_upper_bound,
        :stop_max_upper_bound,
        :vehicle_max_upper_bound,
        :sms_template,
        :sms_concat,
        :enable_external_callback,
        :external_callback_url,
        :external_callback_name,
        :optimization_max_split_size,
        :optimization_cluster_size,
        :optimization_time,
        :optimization_minimal_time,
        :optimization_cost_fixed,
        :optimization_cost_waiting_time,
        :optimization_force_start,
        :planning_date_offset,
        :print_planning_annotating,
        :print_header,
        :print_map,
        :print_stop_time,
        :print_barcode,
        :profile_id,
        :router_id,
        :router_dimension,
        :speed_multiplier,
        :layer_id,
        :uploaded_file,
        :history_cron_hour,
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
        devices: RecursiveParamsHelper.permit_recursive(devices_params)
      )
      return parameters
    else
      allowed_params = [
        :enable_optimization_soft_upper_bound,
        :stop_max_upper_bound,
        :vehicle_max_upper_bound,
        :visit_duration,
        :default_country,
        :with_state,
        :print_planning_annotating,
        :print_header,
        :print_map,
        :print_stop_time,
        :print_barcode,
        :sms_template,
        :sms_concat,
        :external_callback_url,
        :external_callback_name,
        :planning_date_offset,
        :router_id,
        :router_dimension,
        :speed_multiplier,
        :history_cron_hour,
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
        devices: RecursiveParamsHelper.permit_recursive(devices_params)
      ]
      allowed_params << :max_vehicles unless Planner::Application.config.manage_vehicles_only_admin

      p.require(:customer).permit(*allowed_params)
    end
  end
end
