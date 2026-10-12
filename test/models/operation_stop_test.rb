# frozen_string_literal: true

require 'test_helper'

class OperationStopTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @planning = plannings(:planning_one)
    Operation.where(customer_id: @planning.customer_id).delete_all
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
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
end
