# frozen_string_literal: true

require 'test_helper'

class BackfillPastPlanningsTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @planning.update_columns(date: Date.new(2015, 10, 10))
    @stop = stops(:stop_one_one)
    @stop.update_columns(status: 'delivered', status_updated_at: Time.zone.parse('2015-10-10 10:00'))
    file = Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/stop_photo.jpg'), 'image/jpeg')
    assert @stop.attach_photos([file])
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
    @stop&.photos&.purge
    @stop&.signature&.purge if @stop&.signature&.attached?
  end

  test 'a past planning with stop status becomes one historized operation' do
    Operations::BackfillFromPastPlannings.call

    operation = Operation.find_by!(planning_id: @planning.id)
    assert_equal 'historized', operation.status
    assert_equal Date.new(2015, 10, 10), operation.date
    operation_stop = operation.operation_stops.find_by!(stop_id: @stop.id)
    assert_equal 'delivered', operation_stop.status
    assert operation_stop.destination_snapshot.key?('email')
    assert_equal 1, operation_stop.operation_stop_status_events.where(source: 'migration').count
    assert operation_stop.photos.attached?
    assert @stop.reload.photos.attached?
    assert_equal 'delivered', @stop.status

    Operations::BackfillFromPastPlannings.revert
    assert_nil Operation.find_by(planning_id: @planning.id)
    assert @stop.reload.photos.attached?
    assert_equal 'delivered', @stop.status
  end
end
