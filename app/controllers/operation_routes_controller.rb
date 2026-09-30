# frozen_string_literal: true

require 'value_to_boolean'

class OperationRoutesController < ApplicationController
  before_action :authenticate_user!, except: [:mobile, :update_position, :update_status]
  before_action :authenticate_driver!, only: [:mobile, :update_position, :update_status]
  before_action :set_user_route, only: [:show, :media, :transmit]
  before_action :set_driver_route, only: [:mobile, :update_position, :update_status]

  def show
    redirect_to operation_path(@operation_route.operation, route_id: @operation_route.id)
  end

  def transmit
    authorize! :update, @operation_route.operation
    result = Operations::TransmitRoutes.call(operation: @operation_route.operation, routes: [@operation_route])
    redirect_to operation_path(@operation_route.operation, anchor: "route-#{@operation_route.id}"), **transmit_flash(result)
  end

  def media
    @stops = @operation_route.operation_stops.executable
                             .with_attached_photos
                             .with_attached_signature
                             .order(:index)
    @media_groups = @stops.filter_map { |stop|
      documents = stop.document_items
      next if documents.empty?

      { stop: stop, documents: documents }
    }
    render(layout: false) and return if params[:modal].present?

    render layout: 'v2/layouts/application'
  end

  def mobile
    @route = Route.includes_vehicle_usages.find(@operation_route.route_id)
    @stops = @route.stops.includes_destinations_and_stores.only_active
    apply_operation_status(@stops)
    @mobile_position_url = update_position_operation_operation_route_path(@operation_route.operation, @operation_route)
    render 'routes/mobile', locals: {
      route: @route,
      enable_driver_move: ValueToBoolean.value_to_boolean(current_vehicle.customer.devices.dig(:deliver, :driver_move)),
      date: @operation_route.operation.date,
      is_expired: @operation_route.expired?,
      visit_custom_attributes: current_vehicle.customer.custom_attributes.for_visit.visible_on_mobile,
      vehicle_custom_attributes: current_vehicle.customer.custom_attributes.for_vehicle.visible_on_mobile,
      route_custom_attributes: current_vehicle.customer.custom_attributes.for_route.without_related_field.visible_on_mobile,
      stop_visit_custom_attributes: current_vehicle.customer.custom_attributes.for_stop_visit,
      stop_store_custom_attributes: current_vehicle.customer.custom_attributes.for_stop_store,
      start_route_data_custom_attributes: current_vehicle.customer.custom_attributes.for_route.for_related_field('start_route_data').visible_on_mobile,
      stop_route_data_custom_attributes: current_vehicle.customer.custom_attributes.for_route.for_related_field('stop_route_data').visible_on_mobile,
      customer: current_vehicle.customer,
      vehicle: current_vehicle
    }, layout: 'v2/mobile'
  end

  def update_status
    if params.key?(:status)
      leg = params[:leg] == 'arrival' ? 'arrival' : 'departure'
      status = params[:status].presence
      recorded_at = Time.zone.parse(params[:status_updated_at].to_s) || Time.current
      @operation_route.update!(
        "#{leg}_status" => status,
        "#{leg}_status_updated_at" => recorded_at
      )
    end
    merge_custom_attributes(@operation_route, params.dig(:route, :custom_attributes))
    render json: { success: true }
  end

  def update_position
    VehiclePositions::Record.call(
      operation_route: @operation_route,
      lat: params[:latitude] || params[:lat],
      lng: params[:longitude] || params[:lng],
      positioned_at: params[:positioned_at],
      source: 'mobile',
      heading: params[:heading],
      speed: params[:speed],
      accuracy: params[:accuracy],
      altitude: params[:altitude],
      payload: {}
    )
    head :ok
  rescue VehiclePositions::Record::MissingPositionedAt, VehiclePositions::Record::OperationNotOpen
    head :unprocessable_entity
  end

  private

  def apply_operation_status(stops)
    @operation_stops_by_stop_id = @operation_route.operation_stops.where.not(stop_id: nil).index_by(&:stop_id)
    stops.each do |stop|
      operation_stop = @operation_stops_by_stop_id[stop.id]
      next unless operation_stop

      stop.status = operation_stop.status
      stop.status_updated_at = operation_stop.status_updated_at
      stop.custom_attributes = operation_stop.custom_attributes if operation_stop.custom_attributes.present?
    end
    if @operation_route.custom_attributes.present?
      @route.custom_attributes = @operation_route.custom_attributes
    end
    @route.start_route_data.status = @operation_route.departure_status if @route.start_route_data
    @route.stop_route_data.status = @operation_route.arrival_status if @route.stop_route_data
  end

  def merge_custom_attributes(record, incoming)
    return if incoming.blank?

    merged = (record.custom_attributes || {}).merge(incoming.to_unsafe_h.stringify_keys)
    record.update!(custom_attributes: merged)
  end

  def transmit_flash(result)
    if result[:emailed].zero? && result[:sms].zero?
      { alert: t('plannings.edit.deliver_send.singular.fail') }
    else
      { notice: t('plannings.edit.deliver_send.singular.success') }
    end
  end

  def set_user_route
    @operation_route = OperationRoute.joins(:operation).where(operations: { customer_id: current_user.customer_id }).find(params[:id])
    authorize! :read, @operation_route.operation
  end

  def set_driver_route
    @operation_route = OperationRoute.find(params[:id])
    if @operation_route.unassigned || @operation_route.vehicle_id.blank?
      render plain: t('execution.mobile.unassigned'), status: :forbidden
      return
    end
    unless @operation_route.vehicle_id == current_vehicle.id
      head :not_found
    end
  end
end
