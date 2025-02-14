require 'test_helper'

class FleetDemoTest < ActionController::TestCase

  setup do
    @customer = customers(:customer_one)
    @customer.update devices: { fleet_demo: { enable: true } }, enable_vehicle_position: true, enable_stop_status: true
    @service = Planner::Application.config.devices.fleet_demo
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

  test 'should get vehicles positions' do
    o = @service.get_vehicles_pos @customer
    assert_equal 2, o.size
    assert o.all?{ |v| v[:lat] && v[:lng] }
  end

  test 'should code and decode stop id' do
    id = 758944
    code = @service.send(:encode_uid, 'plop', id)
    decode = @service.send(:decode_uid, code)
    assert decode, id
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
