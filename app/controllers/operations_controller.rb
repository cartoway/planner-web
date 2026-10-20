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
    render_page 'operations/index'
  end

  def show
    pull_device_status_if_needed
    @page_routes = paged_routes.to_a
    @located_route_ids = located_route_ids(@page_routes)
    @next_page = next_page
    @selector_routes = selector_routes
    @deliver_demo_enabled = DeliverDemo.enabled?(current_user.customer)
    # Always load send payloads on show — Turbo list→show sends Turbo-Frame: main /
    # X-Turbo-Request-Id, which must not skip these (buttons would stay empty).
    if @operation.open?
      @send_routes = transmittable_routes.to_a
      @send_trackings = destination_trackings_for_send.to_a
    end
    render_page 'operations/show'
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

  def export
    exporter = Operations::Export.new(@operation)
    respond_to do |format|
      format.xlsx do
        send_data exporter.to_xlsx,
                  type: Mime[:xlsx],
                  filename: "#{exporter.basename}.xlsx",
                  disposition: 'attachment'
      end
      format.zip do
        send_data exporter.to_zip.string,
                  type: 'application/zip',
                  filename: "#{exporter.basename}.zip",
                  disposition: 'attachment'
      end
    end
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
    submitted = params[:routes].present? ? params[:routes].to_unsafe_h : {}
    save_driver_contacts!(routes, submitted) if submitted.present?
    sendable = submitted.present? ? routes.select { |route| driver_row_channel(submitted[route.id.to_s] || {}) != 'none' } : routes
    result = transmit_drivers(sendable, submitted)
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
    trackings = destination_trackings_for_send.to_a
    submitted = params[:trackings].present? ? params[:trackings].to_unsafe_h : {}
    save_destination_contacts!(trackings, submitted) if submitted.present?
    sendable = submitted.present? ? trackings.select { |tracking| destination_row_channel(submitted[tracking.id.to_s] || {}) != 'none' } : trackings
    result = transmit_destination_rows(sendable, submitted)
    redirect_to operation_path(@operation), **destination_transmit_flash(result)
  rescue ArgumentError
    redirect_to operation_path(@operation), alert: t('operations.show.sms_unavailable')
  end

  def update
    if @operation.update(operation_params)
      notice =
        if @operation.saved_change_to_name?
          t('operations.show.name_updated')
        elsif @operation.saved_change_to_ref?
          t('operations.show.ref_updated')
        else
          t('operations.show.date_updated')
        end
      respond_to do |format|
        format.html { redirect_to operation_path(@operation), notice: notice }
        format.json { render json: { name: @operation.name, ref: @operation.ref, date: @operation.date } }
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
    return if turbo_refresh_request?
    return unless @operation.open?
    return unless current_user.customer.device.available_stop_status?

    DeviceService.new(customer: current_user.customer).fetch_stops_status(@operation)
  rescue StandardError => e
    Rails.logger.warn("operation device status pull failed: #{e.class}: #{e.message}")
  end

  # Partial Turbo Frame updates only (e.g. demo_actions). "#main" is the layout frame
  # used for list→show navigations and must run full show setup (device pull, etc.).
  def turbo_refresh_request?
    frame = request.headers['Turbo-Frame'].to_s
    frame.present? && frame != 'main'
  end

  def operation_params
    params.require(:operation).permit(:date, :name, :ref)
  end

  def historize_operation
    DeliverDemo::Control.stop!(@operation)
    @operation.update!(status: 'historized', closed_at: Time.current)
    redirect_to operation_path(@operation), notice: t('operations.historized')
  end

  def transmittable_routes
    @operation.operation_routes.planned.where.not(vehicle_id: nil).includes(:vehicle, :operation, route: { vehicle_usage: :vehicle })
  end

  def save_driver_contacts!(routes, submitted)
    by_id = routes.index_by { |route| route.id.to_s }
    submitted.each do |id, row|
      route = by_id[id.to_s]
      next unless route

      snapshot = (route.vehicle_snapshot || {}).dup
      snapshot['contact_email'] = row['contact_email'].to_s.strip if row.key?('contact_email')
      snapshot['phone_number'] = row['phone_number'].to_s.strip if row.key?('phone_number')
      route.update!(vehicle_snapshot: snapshot)
    end
  end

  def save_destination_contacts!(trackings, submitted)
    OperationDeliveryTracking.preload_visit_stops!(trackings)
    trackings.each do |tracking|
      row = submitted[tracking.id.to_s]
      next unless row

      tracking.visit_stops.each do |stop|
        snapshot = (stop.destination_snapshot || {}).dup
        snapshot['email'] = row['email'].to_s.strip if row.key?('email')
        snapshot['phone_number'] = row['phone_number'].to_s.strip if row.key?('phone_number')
        stop.update!(destination_snapshot: snapshot)
      end
    end
  end

  def transmit_drivers(routes, submitted)
    per_row = submitted.present? && submitted.values.any? { |row| row['channel'].present? }
    if per_row
      email_routes = []
      sms_routes = []
      routes.each do |route|
        case driver_row_channel(submitted[route.id.to_s] || {})
        when 'email'
          email_routes << route if contact_present?(route, 'email')
        when 'sms'
          sms_routes << route if contact_present?(route, 'sms')
        end
      end
      return {
        emailed: email_routes.count { |route| Operations::TransmitRoutes.send_email(route) },
        sms: sms_routes.empty? ? 0 : Operations::SendDriverSms.call(operation: @operation, routes: sms_routes)
      }
    end

    case params[:channel]
    when 'email'
      sendable = routes.select { |route| legacy_driver_send?(route, submitted) && contact_present?(route, 'email') }
      { emailed: sendable.count { |route| Operations::TransmitRoutes.send_email(route) }, sms: 0 }
    when 'sms'
      sendable = routes.select { |route| legacy_driver_send?(route, submitted) && contact_present?(route, 'sms') }
      { emailed: 0, sms: Operations::SendDriverSms.call(operation: @operation, routes: sendable) }
    else
      Operations::TransmitRoutes.call(operation: @operation, routes: routes)
    end
  end

  def transmit_destination_rows(trackings, submitted)
    email_trackings = []
    sms_trackings = []
    trackings.each do |tracking|
      row = submitted[tracking.id.to_s] || {}
      channel = destination_row_channel(row)
      case channel
      when 'email'
        email_trackings << tracking if destination_contact_present?(tracking, 'email')
      when 'sms'
        sms_trackings << tracking if destination_contact_present?(tracking, 'sms')
      when 'none'
        next
      else
        # Legacy top-level channel without per-row channel.
        case params[:channel]
        when 'email' then email_trackings << tracking if destination_contact_present?(tracking, 'email')
        when 'sms' then sms_trackings << tracking if destination_contact_present?(tracking, 'sms')
        end
      end
    end
    {
      emailed: email_trackings.empty? ? 0 : Operations::SendDestinationEmail.call(operation: @operation, trackings: email_trackings),
      sms: sms_trackings.empty? ? 0 : Operations::SendDestinationSms.call(operation: @operation, trackings: sms_trackings)
    }
  end

  def driver_row_channel(row)
    return row['channel'].to_s if row['channel'].present?
    return params[:channel].to_s if row['send'].present? && params[:channel].present?
    return 'none' if row['send'].blank? && params[:routes].present?

    params[:channel].presence || 'email'
  end

  def destination_row_channel(row)
    return row['channel'].to_s if row['channel'].present?
    return params[:channel].to_s if row['send'].present? && params[:channel].present?
    return 'none' if row['send'].blank? && params[:trackings].present?

    params[:channel].presence || 'none'
  end

  def legacy_driver_send?(route, submitted)
    return true if submitted.blank?

    row = submitted[route.id.to_s] || {}
    row['send'].present? || row['channel'].present?
  end

  def contact_present?(route, channel)
    channel == 'sms' ? route.driver_phone.present? : route.driver_email.present?
  end

  def destination_contact_present?(tracking, channel)
    stop = tracking.visit_stops.first
    snap = stop&.destination_snapshot || {}
    if channel == 'sms'
      snap['phone_number'].presence || tracking.destination&.phone_number
    else
      snap['email'].presence || tracking.destination&.email
    end.present?
  end

  def transmit_flash(result, _scope = nil)
    emailed = result[:emailed].to_i
    sms = result[:sms].to_i
    if emailed.zero? && sms.zero?
      { alert: t('operations.show.drivers_send_fail') }
    else
      { notice: send_channel_success_message(emailed, sms) }
    end
  end

  def destination_transmit_flash(result)
    emailed = result[:emailed].to_i
    sms = result[:sms].to_i
    if emailed.zero? && sms.zero?
      { alert: t('operations.show.destinations_send_fail') }
    else
      { notice: send_channel_success_message(emailed, sms) }
    end
  end

  def send_channel_success_message(emailed, sms)
    if emailed.positive? && sms.positive?
      t('operations.show.send_success_email_sms', email: emailed, sms: sms)
    elsif emailed.positive?
      t('operations.show.send_success_email', count: emailed)
    else
      t('operations.show.send_success_sms', count: sms)
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
    trackings = @operation.operation_delivery_trackings.with_destination.to_a
    OperationDeliveryTracking.preload_visit_stops!(trackings)
    trackings
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
    @filtered_routes.includes_for_show.offset((page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def next_page
    @filtered_routes.offset(page * PER_PAGE).exists? ? page + 1 : nil
  end
end
