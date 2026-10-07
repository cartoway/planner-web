# frozen_string_literal: true

require 'test_helper'

class OperationStopDetailTest < ActionController::TestCase
  tests OperationStopsController

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    sign_in users(:user_one)
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @stop = @operation.operation_stops.where(kind: 'visit').order(:index).first
    OperationStops::RecordStatus.call(operation_stop: @stop, status: 'delivered', recorded_at: Time.zone.parse('2026-09-25 11:00'), source: 'mobile')
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'actual time and status history show the day offset from the operation date' do
    Time.use_zone('Hawaii') do
      # Update via the association the clock reads (setup may have cached another Operation instance).
      @stop.operation_route.operation.update!(date: Date.new(2026, 9, 30))
      @stop.update!(status_updated_at: Time.zone.local(2026, 9, 30, 9, 0))
      assert_equal '09:00', @stop.actual_clock

      @stop.update!(status_updated_at: Time.zone.local(2026, 9, 29, 22, 5))
      @stop.operation_stop_status_events.update_all(recorded_at: Time.zone.local(2026, 10, 1, 11, 0))
      assert_equal '22:05 (J-1)', @stop.reload.actual_clock
    end

    get :show, params: { id: @stop.id }

    assert_response :success
    assert_includes response.body, '22:05 (J-1)'
    assert_includes response.body, '11:00 (J+1)'
    assert_includes response.body, I18n.t('operations.show.arrival')
    assert_includes response.body, I18n.t('operations.show.departure')
  end

  test 'delay is computed from planned and actual departure' do
    day = @operation.date
    @stop.update_columns(
      stop_snapshot: @stop.stop_snapshot.merge('time' => 9 * 3600),
      visit_snapshot: (@stop.visit_snapshot || {}).merge('duration' => 10 * 60),
      status_updated_at: Time.zone.local(day.year, day.month, day.day, 9, 25)
    )

    assert_equal 15, @stop.delay_minutes
    assert_equal '09:00', @stop.planned_arrival_clock
    assert_equal '09:10', @stop.planned_departure_clock
    assert_equal '09:15', @stop.actual_arrival_clock
    assert_equal '09:25', @stop.actual_departure_clock
  end

  test 'show renders the stop detail and status history for the sidebar' do
    get :show, params: { id: @stop.id }
    assert_response :success
    assert_includes response.body, 'form_sidebar'
    assert_includes response.body, @stop.destination_snapshot['name']
    assert_includes response.body, 'operation-timeline'
    assert_includes response.body, 'is-delivered is-latest'
    @stop.update!(visit_snapshot: @stop.visit_snapshot.merge(
      'duration' => 600,
      'time_window_start_1' => 10 * 3600,
      'time_window_end_1' => 12 * 3600,
      'time_window_start_2' => 14 * 3600,
      'time_window_end_2' => 16 * 3600
    ))
    get :show, params: { id: @stop.id }
    assert_includes response.body, '00:10:00'
    assert_includes response.body, '10:00 – 12:00 et 14:00 – 16:00'
    assert_includes response.body, I18n.t('operations.show.time_windows')
    assert_includes response.body, I18n.t('plannings.edit.stop_status.delivered')
    assert_includes response.body, delivery_note_operation_stop_path(@stop)
  end

  test 'show renders status reset in the timeline' do
    OperationStops::RecordStatus.call(
      operation_stop: @stop,
      status: nil,
      recorded_at: Time.zone.parse('2026-09-25 12:00'),
      source: 'mobile'
    )

    get :show, params: { id: @stop.id }

    assert_response :success
    assert_includes response.body, 'is-none is-latest'
    assert_includes response.body, I18n.t('operations.show.status_reset')
  end

  test 'transferred stop hides late badge and actual clock in the sidebar' do
    target = @operation.operation_routes.planned.where.not(id: @stop.operation_route_id).detect { |route| route.route_id.present? }
    skip 'Need a second vehicle route in the operation' unless target

    OperationStops::Transfer.call(
      operation_stop: @stop,
      target_operation_route: target,
      recorded_at: Time.zone.parse('2026-09-25 18:00'),
      source: 'mobile'
    )

    get :show, params: { id: @stop.id }

    assert_response :success
    assert_nil @stop.reload.actual_clock
    assert_nil @stop.delay_minutes
    assert_select '.badge.text-bg-warning', count: 0
    assert_select '.operation-time-block .operation-split div:last-child strong', text: '—'
  end

  test 'rest sidebar keeps schedule and timeline without details' do
    rest = @operation.operation_stops.find_by!(kind: 'rest')
    OperationStops::RecordStatus.call(
      operation_stop: rest,
      status: 'started',
      recorded_at: Time.zone.parse('2026-09-25 12:00'),
      source: 'mobile'
    )

    get :show, params: { id: rest.id }

    assert_response :success
    assert_includes response.body, I18n.t('operations.show.planned')
    assert_includes response.body, I18n.t('operations.show.actual')
    assert_includes response.body, 'operation-timeline'
    assert_includes response.body, I18n.t('plannings.edit.stop_rest_status.started')
    assert_not_includes response.body, I18n.t('operations.show.details')
    assert_not_includes response.body, I18n.t('operations.show.address')
    assert_not_includes response.body, I18n.t('operations.show.proof')
  end

  test 'delivery note opens the printable note for a delivered visit' do
    get :delivery_note, params: { id: @stop.id }
    assert_response :success
    assert_includes response.body, I18n.t('stops.delivery_note.title')
    assert_includes response.body, @stop.destination_snapshot['name']
    assert_includes response.body, 'print-layout'
    assert_includes response.body, 'v2/application'
    assert_includes response.body, '.delivery-note-title-block'
  end

  test 'show renders photos from the operation stop and the planning stop' do
    @stop.photos.attach(io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')), filename: 'operation_stop_photo.jpg', content_type: 'image/jpeg')
    @stop.stop.photos.attach(io: File.open(Rails.root.join('test/fixtures/files/stop_photo.jpg')), filename: 'planning_stop_photo.jpg', content_type: 'image/jpeg')

    get :show, params: { id: @stop.id }

    assert_response :success
    assert_includes response.body, 'operation-stop-documents'
    assert_includes response.body, 'operation_stop_photo.jpg'
    assert_includes response.body, 'planning_stop_photo.jpg'
  ensure
    @stop.photos.purge
    @stop.stop&.photos&.purge
  end

  test 'show renders recipient tracking link when token is still valid' do
    tracking = @operation.operation_delivery_trackings.find_by(destination_id: @stop.destination_id)
    assert tracking.present?

    get :show, params: { id: @stop.id }
    assert_response :success
    assert_includes response.body, delivery_tracking_path(token: tracking.token)
    assert_includes response.body, I18n.t('operations.show.recipient_tracking')

    tracking.update_columns(expires_at: 1.hour.ago)
    get :show, params: { id: @stop.id }
    assert_response :success
    assert_not_includes response.body, delivery_tracking_path(token: tracking.token)
  end

  test 'active delivery tracking resolves via destination snapshot when fk is cleared' do
    tracking = @operation.operation_delivery_trackings.find_by(destination_id: @stop.destination_id)
    assert_equal tracking, @stop.active_delivery_tracking

    @stop.update_columns(destination_id: nil)
    assert_nil @stop.reload.destination_id
    assert_equal tracking.id, @stop.active_delivery_tracking.id
  end
end
