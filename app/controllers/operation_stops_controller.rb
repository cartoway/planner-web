# frozen_string_literal: true

class OperationStopsController < ApplicationController
  layout 'v2/application', only: :index
  before_action :authenticate_user!, only: [:index, :show, :delivery_note, :desk]
  before_action :authenticate_driver!, only: [:edit, :update]
  before_action :set_user_stop, only: [:show, :delivery_note, :desk]
  before_action :set_driver_stop, only: [:edit, :update]

  def index
    authorize! :read, Operation
    from = params[:from].presence&.to_date || 90.days.ago.to_date
    to = params[:to].presence&.to_date || Date.current
    @stops = OperationStop.search_by_destination_info(
      query: params[:q],
      from: from,
      to: to,
      destination_id: params[:destination_id],
      customer_id: current_user.customer_id
    ).includes(operation_route: :operation).order('operations.date DESC', :index).limit(50)
    @from = from
    @to = to
    render 'operation_stops/index', layout: 'v2/layouts/application'
  end

  def show
    authorize! :read, @operation_stop.operation_route.operation
    render 'operation_stops/show', layout: false
  end

  def delivery_note
    authorize! :read, @operation_stop.operation_route.operation
    raise ActiveRecord::RecordNotFound unless @operation_stop.delivery_note_available?
    raise ActiveRecord::RecordNotFound unless @operation_stop.stop.is_a?(StopVisit)

    assigns = Operations::DeliveryNoteDocument.assigns(@operation_stop)
    assigns.each { |key, value| instance_variable_set("@#{key}", value) }
    render 'stops/delivery_note', layout: 'v2/print'
  end

  def desk
    authorize! :update, @operation_stop.operation_route.operation
    if params.key?(:status)
      OperationStops::RecordStatus.call(
        operation_stop: @operation_stop,
        status: params[:status],
        recorded_at: Time.current,
        source: 'backoffice'
      )
    end
    if params.key?(:note)
      attributes = (@operation_stop.custom_attributes || {}).merge('_note' => params[:note].to_s)
      @operation_stop.update!(custom_attributes: attributes)
    end
    redirect_to operation_path(@operation_stop.operation_route.operation, anchor: "stop-#{@operation_stop.id}")
  end

  def edit
    render 'operation_stops/edit', layout: 'v2/mobile'
  end

  def update
    raw = params[:operation_stop].presence || params[:stop] || {}
    save_actual_quantities(raw)
    if raw.key?(:status) || raw.key?('status')
      recorded_at = raw[:status_updated_at].presence || Time.current.iso8601
      OperationStops::RecordStatus.call(
        operation_stop: @operation_stop,
        status: raw[:status],
        eta: raw[:eta],
        recorded_at: recorded_at,
        source: 'mobile',
        actor_ref: current_vehicle.id.to_s,
        payload: {}
      )
    end
    merge_custom_attributes(@operation_stop, raw[:custom_attributes])
    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to mobile_operation_operation_route_path(@operation_stop.operation_route.operation, @operation_stop.operation_route) }
    end
  rescue ArgumentError
    head :unprocessable_entity
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.include?('operation_closed')

    head :unprocessable_entity
  end

  private

  def save_actual_quantities(raw)
    incoming = raw[:actual_quantities] || raw['actual_quantities']
    return if incoming.blank?

    stored = (@operation_stop.actual_quantities || {}).deep_dup
    hash = incoming.respond_to?(:to_unsafe_h) ? incoming.to_unsafe_h : incoming.to_h
    hash.each do |kind, units|
      kind = kind.to_s
      next unless %w[deliveries pickups].include?(kind)
      next unless units.respond_to?(:each)

      stored[kind] ||= {}
      units.each do |unit_id, value|
        stored[kind][unit_id.to_s] = value.to_s.strip == '' ? nil : value.to_f
      end
    end
    @operation_stop.update!(actual_quantities: stored)
  end

  def merge_custom_attributes(record, incoming)
    return if incoming.blank?

    merged = (record.custom_attributes || {}).merge(incoming.to_unsafe_h.stringify_keys)
    record.update!(custom_attributes: merged)
  end

  def set_user_stop
    @operation_stop = OperationStop.joins(operation_route: :operation)
                                   .where(operations: { customer_id: current_user.customer_id })
                                   .with_attached_photos
                                   .with_attached_signature
                                   .includes(:operation_stop_status_events)
                                   .find(params[:id])
  end

  def set_driver_stop
    @operation_stop = OperationStop.find(params[:id])
    route = @operation_stop.operation_route
    if route.vehicle_id.blank?
      render plain: t('execution.mobile.unassigned'), status: :forbidden
      return
    end
    unless route.vehicle_id == current_vehicle.id
      head :not_found
    end
  end

  def stop_params
    params.require(:operation_stop).permit(:status, :status_updated_at, :eta)
  end
end
