# frozen_string_literal: true

require 'test_helper'

class VehiclePositionsRecordTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
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
end
