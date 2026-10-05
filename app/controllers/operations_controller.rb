# frozen_string_literal: true

class OperationsController < ApplicationController
  layout 'v2/application'
  include V2Layout

  before_action :authenticate_user!
  load_and_authorize_resource
  before_action :set_filtered_routes, only: [:show, :routes, :map, :search_stops]

  PER_PAGE = 20

  def index
    @operations = @operations.includes(:planning).order(date: :desc, id: :desc)
    @operations = @operations.where(status: params[:status]) if params[:status].present?
    @operations = @operations.where(date: params[:date]) if params[:date].present?
    if params[:q].present?
      q = "%#{Operation.sanitize_sql_like(params[:q].to_s.strip)}%"
      @operations = @operations.where('operations.ref ILIKE :q OR operations.name ILIKE :q', q: q)
    end
    render_v2_page 'operations/index'
  end

  def show
    pull_device_status_if_needed
    @page_routes = paged_routes.to_a
    @located_route_ids = located_route_ids(@page_routes)
    @next_page = next_page
    @selector_routes = selector_routes
    @deliver_demo_enabled = DeliverDemo.enabled?(current_user.customer)
    if @operation.open?
      @send_routes = transmittable_routes.to_a
      @send_trackings = destination_trackings_for_send.to_a
    end
    render_v2_page 'operations/show'
  end

  def demo
    DeliverDemo::Control.start!(@operation)
    respond_demo_actions(notice: t('operations.show.demo_started'))
  rescue DeliverDemo::Control::NotEnabled
    respond_demo_actions(alert: t('operations.show.demo_not_enabled'))
  rescue DeliverDemo::Control::NotOpen, DeliverDemo::Control::AlreadyRunning => e
    respond_demo_actions(alert: e.message)
  end

  def stop_demo
    DeliverDemo::Control.stop!(@operation)
    respond_demo_actions(notice: t('operations.show.demo_stopped'))
  end

  def reset_demo
    DeliverDemo::Control.reset!(@operation)
    redirect_to operation_path(@operation), notice: t('operations.show.demo_reset')
  rescue DeliverDemo::Control::NotEnabled
    redirect_to operation_path(@operation), alert: t('operations.show.demo_not_enabled')
  rescue DeliverDemo::Control::NotOpen => e
    redirect_to operation_path(@operation), alert: e.message
  end

  def fetch_device_status
    DeviceService.new(customer: current_user.customer).fetch_stops_status(@operation)
    respond_to do |format|
      format.html { redirect_to operation_path(@operation) }
      format.json { head :no_content }
    end
  end

  def routes
    @page_routes = paged_routes.to_a
    @located_route_ids = located_route_ids(@page_routes)
    @next_page = next_page
    render partial: 'operations/route_list', layout: false
  end

  def map
    response.headers['Cache-Control'] = 'no-store'
    routes = @filtered_routes.includes(:operation_stops, :vehicle_positions, route: :route_geojson).to_a
    render json: Operations::MapGeojson.call(operation: @operation, routes: routes)
  end

  def search_stops
    stops = @operation.operation_stops.executable.where(operation_route_id: @filtered_routes.select(:id))
    if params[:q].present?
      escaped = "%#{OperationStop.sanitize_sql_like(params[:q].strip)}%"
      stops = stops.where(<<~SQL.squish, q: escaped)
        destination_snapshot->>'name' ILIKE :q
        OR destination_snapshot->>'ref' ILIKE :q
        OR destination_snapshot->>'street' ILIKE :q
        OR destination_snapshot->>'city' ILIKE :q
        OR store_snapshot->>'name' ILIKE :q
      SQL
    end
    render json: stops.order(:index).limit(50).map { |stop|
      {
        id: stop.id,
        operation_route_id: stop.operation_route_id,
        label: stop.address_label,
        index: stop.index
      }
    }
  end

  def close
    historize_operation
  end

  def cancel
    historize_operation
  end

  def transmit
    routes = transmittable_routes.to_a
    routes = save_driver_contacts!(routes) if params[:routes].present?
    result = case params[:channel]
             when 'email'
               { emailed: routes.count { |route| Operations::TransmitRoutes.send_email(route) }, sms: 0 }
             when 'sms'
               { emailed: 0, sms: Operations::SendDriverSms.call(operation: @operation, routes: routes) }
             else
               Operations::TransmitRoutes.call(operation: @operation, routes: routes)
             end
    redirect_to operation_path(@operation), **transmit_flash(result, :plural)
  rescue ArgumentError
    redirect_to operation_path(@operation), alert: t('operations.show.sms_unavailable')
  end

  def send_driver_sms
    routes = transmittable_routes
    count = Operations::SendDriverSms.call(operation: @operation, routes: routes)
    redirect_to operation_path(@operation), notice: t('operations.show.sms_sent', count: count)
  rescue ArgumentError
    redirect_to operation_path(@operation), alert: t('operations.show.sms_unavailable')
  end

  def transmit_destinations
    trackings = destination_trackings_for_send
    result = case params[:channel]
             when 'email'
               { emailed: Operations::SendDestinationEmail.call(operation: @operation, trackings: trackings), sms: 0 }
             when 'sms'
               { emailed: 0, sms: Operations::SendDestinationSms.call(operation: @operation, trackings: trackings) }
             else
               { emailed: 0, sms: 0 }
             end
    redirect_to operation_path(@operation), **destination_transmit_flash(result)
  rescue ArgumentError
    redirect_to operation_path(@operation), alert: t('operations.show.sms_unavailable')
  end

  def update
    if @operation.update(operation_params)
      notice = @operation.saved_change_to_name? ? t('operations.show.name_updated') : t('operations.show.date_updated')
      respond_to do |format|
        format.html { redirect_to operation_path(@operation), notice: notice }
        format.json { render json: { name: @operation.name, date: @operation.date } }
      end
    else
      message = @operation.errors.full_messages.to_sentence
      respond_to do |format|
        format.html { redirect_to operation_path(@operation), alert: message }
        format.json { render json: { error: message }, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::RecordNotUnique
    respond_to do |format|
      format.html { redirect_to operation_path(@operation), alert: t('operations.show.date_taken') }
      format.json { render json: { error: t('operations.show.date_taken') }, status: :unprocessable_entity }
    end
  end

  def destroy
    @operation.destroy!
    redirect_to operations_path, notice: t('operations.index.destroyed')
  end

  private

  def pull_device_status_if_needed
    return unless @operation.open?
    return unless current_user.customer.enable_stop_status?
    return unless current_user.customer.device.available_stop_status?

    DeviceService.new(customer: current_user.customer).fetch_stops_status(@operation)
  rescue StandardError => e
    Rails.logger.warn("operation device status pull failed: #{e.class}: #{e.message}")
  end

  def operation_params
    params.require(:operation).permit(:date, :name)
  end

  def historize_operation
    DeliverDemo::Control.stop!(@operation)
    @operation.update!(status: 'historized', closed_at: Time.current)
    redirect_to operation_path(@operation), notice: t('operations.historized')
  end

  def transmittable_routes
    @operation.operation_routes.planned.where.not(vehicle_id: nil).includes(:vehicle, :operation, route: { vehicle_usage: :vehicle })
  end

  def save_driver_contacts!(routes)
    field = params[:channel] == 'sms' ? 'phone_number' : 'contact_email'
    submitted = params[:routes].to_unsafe_h
    by_id = routes.index_by { |route| route.id.to_s }
    submitted.each do |id, row|
      route = by_id[id.to_s]
      next unless route

      snapshot = (route.vehicle_snapshot || {}).dup
      snapshot[field] = row[field].to_s.strip
      route.update!(vehicle_snapshot: snapshot)
    end
    routes.select { |route| submitted.dig(route.id.to_s, 'send').present? && route.vehicle_snapshot[field].present? }
  end

  def transmit_flash(result, scope)
    if result[:emailed].zero? && result[:sms].zero?
      { alert: t("plannings.edit.deliver_send.#{scope}.fail") }
    else
      { notice: t("plannings.edit.deliver_send.#{scope}.success") }
    end
  end

  def destination_transmit_flash(result)
    if result[:emailed].zero? && result[:sms].zero?
      { alert: t('operations.show.destinations_send_fail') }
    else
      { notice: t('operations.show.destinations_send_success', sms: result[:sms], email: result[:emailed]) }
    end
  end

  # Turbo Frame keeps the map/Stimulus board; full redirect only for non-Turbo clients.
  def respond_demo_actions(notice: nil, alert: nil)
    @deliver_demo_enabled = DeliverDemo.enabled?(current_user.customer)
    if turbo_frame_request? || request.format.turbo_stream?
      render turbo_stream: turbo_stream.replace('operation_demo_actions', partial: 'operations/demo_actions')
    else
      redirect_to operation_path(@operation), notice: notice, alert: alert
    end
  end

  def destination_trackings_for_send
    OperationDeliveryTracking.ensure_for!(@operation)
    trackings = @operation.operation_delivery_trackings.includes(:destination).to_a
    return trackings if params[:trackings].blank?

    submitted = params[:trackings].to_unsafe_h
    trackings.select { |tracking| submitted.dig(tracking.id.to_s, 'send').present? }
  end

  def set_filtered_routes
    rel = @operation.operation_routes.active_sync
    if params[:selector].present?
      rel = rel.where("vehicle_snapshot->>'name' = ?", params[:selector])
    end
    if params[:q].present?
      escaped = "%#{OperationRoute.sanitize_sql_like(params[:q].strip)}%"
      rel = rel.where(<<~SQL.squish, q: escaped)
        COALESCE(vehicle_snapshot->>'name', '') ILIKE :q
        OR COALESCE(operation_routes.ref, '') ILIKE :q
        OR COALESCE(route_snapshot->>'ref', '') ILIKE :q
      SQL
    end
    @filtered_routes = rel.order(Arel.sql('"operation_routes"."index" ASC NULLS FIRST, operation_routes.id'))
  end

  def page
    [params[:page].to_i, 1].max
  end

  def located_route_ids(routes)
    ids = routes.map(&:id)
    return Set.new if ids.empty?

    VehiclePosition.where(operation_route_id: ids).distinct.pluck(:operation_route_id).to_set
  end

  def selector_routes
    @operation.operation_routes.active_sync.order(Arel.sql('"operation_routes"."index" ASC NULLS FIRST, operation_routes.id'))
  end

  def paged_routes
    @filtered_routes.includes(:operation, :vehicle, { route: :route_data }, operation_stops: :operation_stop_status_events).offset((page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def next_page
    @filtered_routes.offset(page * PER_PAGE).exists? ? page + 1 : nil
  end
end
