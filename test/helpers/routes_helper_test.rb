require 'test_helper'

class RoutesHelperTest < ActionView::TestCase
  include RoutesHelper

  test 'route_devices omits nil or blank vehicle device values' do
    route = routes(:route_one_one)
    route.vehicle_usage.vehicle.update!(devices: { sopac_ids: nil, stg_telematics_vehicle_id: nil })

    assert_equal({}, route_devices(nil, route))
  end
end
