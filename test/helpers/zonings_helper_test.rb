require 'test_helper'

class ZoningsHelperTest < ActionView::TestCase
  test 'zoning_vehicles uses preloaded vehicle_usage_sets' do
    zoning = zonings(:zoning_one)
    Zoning.includes(
      customer: { vehicle_usage_sets: Planning::VEHICLE_USAGE_SET_PRELOAD }
    ).find(zoning.id).tap { |z| zoning = z }

    queries = count_queries(/FROM "vehicle_usages"/) do
      vehicles = zoning_vehicles(zoning, nil, active: true)
      assert vehicles.any?
      assert vehicles.first.association(:router).loaded? || vehicles.first.router_id.nil?
    end

    assert_equal 0, queries, 'expected no fresh vehicle_usages query when sets are preloaded'
  end
end
