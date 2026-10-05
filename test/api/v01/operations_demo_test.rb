# frozen_string_literal: true

require 'test_helper'

class V01::OperationsDemoTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    Operation.where(customer_id: @customer.id).delete_all
    Delayed::Job.delete_all
    @operation = Operations::PublishFromPlanning.call(
      planning: @planning,
      route_ids: [routes(:route_one_one).id]
    )
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
    Delayed::Job.delete_all
  end

  test 'starts and stops demo when deliver demo is enabled' do
    @customer.update!(devices: { deliver: { enable: true, demo: true } })

    post "/api/0.1/operations/#{@operation.id}/demo.json?api_key=testkey1"
    assert_equal 200, last_response.status, last_response.body
    assert @operation.reload.demo_job_id.present?

    delete "/api/0.1/operations/#{@operation.id}/demo.json?api_key=testkey1"
    assert_equal 204, last_response.status
    assert_nil @operation.reload.demo_job_id
  end

  test 'rejects demo start when option is off' do
    @customer.update!(devices: { deliver: { enable: true, demo: false } })

    post "/api/0.1/operations/#{@operation.id}/demo.json?api_key=testkey1"
    assert_equal 403, last_response.status, last_response.body
    assert_nil @operation.reload.demo_job_id
  end

  test 'resets demo execution state' do
    @customer.update!(devices: { deliver: { enable: true, demo: true } })
    route = @operation.operation_routes.first
    stop = @operation.operation_stops.executable.first
    OperationStops::RecordStatus.call(
      operation_stop: stop,
      status: 'intransit',
      recorded_at: Time.zone.parse("#{@operation.date} 10:00"),
      source: 'demo'
    )

    post "/api/0.1/operations/#{@operation.id}/demo/reset.json?api_key=testkey1"
    assert_equal 200, last_response.status, last_response.body
    assert_nil stop.reload.status
    assert_equal 0, stop.operation_stop_status_events.count
    assert_nil @operation.reload.demo_job_id
  end
end
