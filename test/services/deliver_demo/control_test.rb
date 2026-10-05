# frozen_string_literal: true

require 'test_helper'

class DeliverDemoControlTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    @customer.update!(devices: { deliver: { enable: true, demo: true } })
    @operation = Operations::PublishFromPlanning.call(
      planning: @planning,
      route_ids: [routes(:route_one_one).id]
    )
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
    Delayed::Job.delete_all
  end

  test 'start enqueues a demo job and stop destroys it' do
    DeliverDemo::Control.start!(@operation)
    @operation.reload
    assert @operation.demo_job_id.present?
    assert Delayed::Job.exists?(id: @operation.demo_job_id)

    DeliverDemo::Control.stop!(@operation)
    @operation.reload
    assert_nil @operation.demo_job_id
    assert_equal 0, Delayed::Job.where("handler LIKE '%DeliverDemoJob%'").count
  end

  test 'start rejects when demo option is off' do
    @customer.update!(devices: { deliver: { enable: true, demo: false } })
    assert_raises(DeliverDemo::Control::NotEnabled) do
      DeliverDemo::Control.start!(@operation)
    end
  end

  test 'reset clears positions statuses and stops the job' do
    route = @operation.operation_routes.first
    stop = route.operation_stops.executable.first
    OperationStops::RecordStatus.call(
      operation_stop: stop,
      status: 'intransit',
      recorded_at: Time.zone.parse("#{@operation.date} 09:00"),
      source: 'demo'
    )
    VehiclePositions::Record.call(
      operation_route: route,
      lat: 48.85,
      lng: 2.35,
      positioned_at: Time.zone.parse("#{@operation.date} 09:01"),
      source: 'demo'
    )
    route.update!(departure_status: 'finished', departure_status_updated_at: Time.current)
    DeliverDemo::Control.start!(@operation)

    DeliverDemo::Control.reset!(@operation)
    @operation.reload

    assert_nil @operation.demo_job_id
    assert_equal 0, @operation.vehicle_positions.count
    assert_equal 0, stop.operation_stop_status_events.count
    assert_nil stop.reload.status
    assert_nil route.reload.departure_status
  end
end
