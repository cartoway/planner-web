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
      @operation.update!(date: Date.new(2026, 9, 30))
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
end