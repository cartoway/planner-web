# frozen_string_literal: true

require 'test_helper'

class OperationStopTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @planning = plannings(:planning_one)
    @operation = publish_operation!(planning: @planning)
    @stop = @operation.operation_stops.find_by!(stop_id: stops(:stop_one_one).id)
  end

  teardown do
    @stop&.photos&.purge
    @stop&.signature&.purge if @stop&.signature&.attached?
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'attach_photos rejects empty files' do
    assert_nil @stop.attach_photos([])
    assert @stop.errors[:photos].present?
  end

  test 'attach_photos rejects more than max with translated error' do
    file = -> {
      Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/stop_photo.jpg'), 'image/jpeg')
    }
    ProofAttachments::PHOTO_MAX_COUNT.times { assert @stop.attach_photos([file.call]) }

    assert_nil @stop.attach_photos([file.call])
    message = @stop.errors.full_messages.to_sentence
    assert_match(/#{ProofAttachments::PHOTO_MAX_COUNT}/, message)
    assert_no_match(/Translation missing/i, message)
  end

  test 'attach_photos stores blobs under customer/date prefix' do
    customer_id = @planning.customer_id
    file = Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/stop_photo.jpg'), 'image/jpeg')

    travel_to Time.utc(2026, 9, 18, 12, 0, 0) do
      assert @stop.attach_photos([file])
      key = @stop.photos.last.blob.key
      assert_match %r{\Acustomers/#{customer_id}/2026/09/18/[a-z0-9]{28}\z}, key
    end
  end

  test 'attach_signature stores a single replaceable image' do
    file = Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/stop_photo.jpg'), 'image/jpeg')

    assert @stop.attach_signature(file)
    assert @stop.signature.attached?
    first_blob_id = @stop.signature.blob.id

    travel 2.hours do
      file2 = Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/stop_photo.jpg'), 'image/jpeg')
      assert @stop.attach_signature(file2)
    end

    assert @stop.signature.attached?
    assert_not_equal first_blob_id, @stop.signature.blob.id
    assert_match %r{\Acustomers/\d+/\d{4}/\d{2}/\d{2}/[a-z0-9]{28}\z}, @stop.signature.blob.key
  end

  test 'delivery_note_available? only for delivered or exception visit stops' do
    @stop.update_columns(status: nil)
    assert_not @stop.delivery_note_available?

    @stop.update_columns(status: 'intransit')
    assert_not @stop.delivery_note_available?

    @stop.update_columns(status: 'delivered')
    assert @stop.delivery_note_available?

    @stop.update_columns(status: 'exception')
    assert @stop.delivery_note_available?

    rest = @operation.operation_stops.find { |row| row.kind == 'rest' }
    assert rest
    assert_not rest.delivery_note_available?
  end

  test 'delivery_note_exportable? does not require live stop_id' do
    @stop.update_columns(status: 'delivered', stop_id: nil)
    assert @stop.delivery_note_exportable?
    assert_not @stop.delivery_note_available?
  end

  test 'search_label includes name ref street and city' do
    @stop.update_columns(
      destination_snapshot: @stop.destination_snapshot.merge(
        'name' => 'Chez Dupont',
        'ref' => 'REF-42',
        'street' => '12 rue des Lilas',
        'city' => 'Bordeaux'
      )
    )
    label = @stop.search_label
    assert_includes label, 'Chez Dupont'
    assert_includes label, 'REF-42'
    assert_includes label, '12 rue des Lilas'
    assert_includes label, 'Bordeaux'
  end

  test 'time_window_delay_minutes uses the best matching window not plan deviation' do
    day = @operation.date
    @operation.update_columns(
      planning_snapshot: (@operation.planning_snapshot || {}).merge('enable_strict_within_timewindows' => false)
    )
    @stop.update_columns(
      status: 'delivered',
      stop_snapshot: (@stop.stop_snapshot || {}).merge('time' => 9 * 3600),
      visit_snapshot: (@stop.visit_snapshot || {}).merge(
        'duration' => 10 * 60,
        'time_window_start_1' => 10 * 3600,
        'time_window_end_1' => 11 * 3600,
        'time_window_start_2' => 14 * 3600,
        'time_window_end_2' => 16 * 3600
      ),
      # Arrived 11:20 / left 11:30: 20 min late vs window 1 close, +140 min vs planned departure 09:10
      status_updated_at: Time.zone.local(day.year, day.month, day.day, 11, 30)
    )

    assert_equal 140, @stop.delay_minutes
    assert_equal 20, @stop.time_window_delay_minutes

    board = @stop.operation_route.board
    assert_equal 140, board[:delay]
    assert_equal 20, board[:window_delay]
  end

  test 'time_window_delay_minutes keeps the strict flag frozen on the planning snapshot' do
    day = @operation.date
    @operation.update_columns(
      planning_snapshot: (@operation.planning_snapshot || {}).merge('enable_strict_within_timewindows' => false)
    )
    @stop.update_columns(
      status: 'delivered',
      stop_snapshot: (@stop.stop_snapshot || {}).merge('time' => 9 * 3600),
      visit_snapshot: (@stop.visit_snapshot || {}).merge(
        'duration' => 30 * 60,
        'time_window_start_1' => 10 * 3600,
        'time_window_end_1' => 11 * 3600
      ),
      # Arrival 10:50: non-strict → on time; strict would count service end 11:20 → 20 min late
      status_updated_at: Time.zone.local(day.year, day.month, day.day, 11, 20)
    )

    assert_equal 0, @stop.time_window_delay_minutes

    @planning.customer.update_columns(enable_strict_within_timewindows: true)
    @stop.reload
    assert_equal 0, @stop.time_window_delay_minutes

    @operation.update_columns(
      planning_snapshot: (@operation.planning_snapshot || {}).merge('enable_strict_within_timewindows' => true)
    )
    @stop.reload
    assert_equal 20, @stop.time_window_delay_minutes
  end

  test 'route board window_delay is 0 when on time and nil when no window data' do
    day = @operation.date
    route = @stop.operation_route
    # Isolate board aggregation to this stop only.
    route.operation_stops.where.not(id: @stop.id).update_all(status: nil)
    @operation.update_columns(
      planning_snapshot: (@operation.planning_snapshot || {}).merge('enable_strict_within_timewindows' => false)
    )
    @stop.update_columns(
      status: 'delivered',
      stop_snapshot: (@stop.stop_snapshot || {}).merge('time' => 10 * 3600 + 30 * 60),
      visit_snapshot: (@stop.visit_snapshot || {}).merge(
        'duration' => 10 * 60,
        'time_window_start_1' => 10 * 3600,
        'time_window_end_1' => 11 * 3600,
        'time_window_start_2' => nil,
        'time_window_end_2' => nil
      ),
      status_updated_at: Time.zone.local(day.year, day.month, day.day, 10, 40)
    )
    assert_equal 0, @stop.time_window_delay_minutes
    assert_equal 0, route.board[:window_delay]

    @stop.update_columns(visit_snapshot: (@stop.visit_snapshot || {}).except(
      'time_window_start_1', 'time_window_end_1', 'time_window_start_2', 'time_window_end_2'
    ))
    assert_nil @stop.time_window_delay_minutes
    assert_nil route.reload.board[:window_delay]
  end
end
