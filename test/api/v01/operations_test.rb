# frozen_string_literal: true

require 'test_helper'

class V01::OperationsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @stop = @operation.operation_stops.find_by!(visit_id: visits(:visit_one).id)
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'returns the operation from snapshots' do
    get "/api/0.1/operations/#{@operation.id}.json?api_key=testkey1"
    assert last_response.ok?, last_response.body
    body = JSON.parse(last_response.body)
    assert_equal @operation.name, body['name']
    assert body['operation_routes'].any?
    assert body['operation_routes'].first['operation_stops'].first['destination_snapshot']
  end

  test 'posts a status event' do
    post "/api/0.1/operations/#{@operation.id}/stops/#{@stop.id}/status.json?api_key=testkey1",
         status: 'delivered',
         recorded_at: '2026-09-25T10:00:00Z'
    assert_equal 201, last_response.status
    @stop.reload
    assert_equal 'delivered', @stop.status
    assert_equal 1, @stop.operation_stop_status_events.count
  end
end
