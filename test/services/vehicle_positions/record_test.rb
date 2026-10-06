# frozen_string_literal: true

require 'test_helper'

class VehiclePositionsRecordTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @route = @operation.operation_routes.where(unassigned: false).first
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'stores the gps time and rejects a point without positioned_at' do
    assert_raises(VehiclePositions::Record::MissingPositionedAt) do
      VehiclePositions::Record.call(operation_route: @route, lat: 48.8, lng: 2.3, positioned_at: nil)
    end

    older = Time.zone.parse('2026-09-25 08:00')
    newer = Time.zone.parse('2026-09-25 09:00')
    VehiclePositions::Record.call(operation_route: @route, lat: 48.1, lng: 2.1, positioned_at: newer, source: 'mobile')
    VehiclePositions::Record.call(operation_route: @route, lat: 48.0, lng: 2.0, positioned_at: older, source: 'mobile')

    latest = @route.latest_position
    assert_equal newer, latest.positioned_at
    assert_equal @route.id, latest.operation_route_id
    assert latest.received_at.present?
    refute_equal latest.positioned_at, latest.received_at
  end

  test 'rejects positions once the operation is historized' do
    @operation.update!(status: 'historized', closed_at: Time.current)
    assert_raises(VehiclePositions::Record::OperationNotOpen) do
      VehiclePositions::Record.call(operation_route: @route, lat: 48.8, lng: 2.3, positioned_at: Time.current)
    end
  end

  test 'live-only mode keeps a single point per route' do
    @customer.update!(vehicle_position_keep_trace: false)
    VehiclePositions::Record.call(operation_route: @route, lat: 48.0, lng: 2.0, positioned_at: 1.hour.ago)
    VehiclePositions::Record.call(operation_route: @route, lat: 48.1, lng: 2.1, positioned_at: Time.current)

    assert_equal 1, @route.vehicle_positions.count
    assert_in_delta 48.1, @route.latest_position.lat, 0.0001
  end

  test 'broadcasts the vehicle pin so the map marker moves without a geojson reload' do
    Turbo::StreamsChannel.expects(:broadcast_stream_to).once.with { |operation, kwargs|
      html = kwargs[:content].to_s
      operation == @operation &&
        html.include?('refresh_vehicle') &&
        html.include?(%(data-operation-route-id="#{@route.id}")) &&
        html.include?('48.850000') &&
        html.include?('2.350000')
    }
    VehiclePositions::Record.call(
      operation_route: @route,
      lat: 48.85,
      lng: 2.35,
      positioned_at: Time.current,
      source: 'demo'
    )
  end

  test 'purge_stale removes points older than customer retention' do
    @customer.update!(vehicle_position_retention_days: 60)
    VehiclePositions::Record.call(operation_route: @route, lat: 48.0, lng: 2.0, positioned_at: 90.days.ago)
    VehiclePositions::Record.call(operation_route: @route, lat: 48.1, lng: 2.1, positioned_at: 10.days.ago)

    deleted = VehiclePosition.purge_stale!
    assert_operator deleted, :>=, 1
    assert_equal 1, @route.vehicle_positions.count
    assert_in_delta 48.1, @route.latest_position.lat, 0.0001
  end
end
