require 'test_helper'

class DeliverTest < ActionController::TestCase

  setup do
    @customer = customers(:customer_one)
    @customer.update devices: { deliver: { enable: true } }, enable_vehicle_position: true, enable_stop_status: true
    @service = Planner::Application.config.devices.deliver
  end

  test 'should send route' do
    assert_nothing_raised do
      @service.send_route @customer, routes(:route_one_one)
    end
  end

  test 'should clear route' do
    assert_nothing_raised do
      @service.clear_route @customer, routes(:route_one_one)
    end
  end

  test 'should get stop status' do
    planning = plannings(:planning_one)
    planning.routes.select(&:vehicle_usage_id).each{ |r|
      r.last_sent_at = Time.now.utc
    }
    planning.save

    planning.fetch_stops_status
    planning.routes.select(&:vehicle_usage_id).each{ |r|
      # FIXME: stop status is not saved for StopVisit for vehicle_three
      # assert r.stops.select(&:active).all?{ |s| s.status } if r.vehicle_usage.vehicle.name != 'vehicle_three'
    }
  end
end
