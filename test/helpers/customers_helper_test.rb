require 'test_helper'

class CustomersHelperTest < ActionView::TestCase

  test 'display warning information if at least one vehicle have unauthorized router for profile' do
    vehicles(:vehicle_one).update_attribute(:router_id, routers(:router_osrm).id)
    assert has_vehicle_with_unauthorized_router(customers(:customer_one))
  end

  test 'do not diplay warning information if all vehicles are authorized for profile' do
    refute has_vehicle_with_unauthorized_router(customers(:customer_one))
  end

  test 'display warning information if at least one user have unauthorized layer for profile' do
    customers(:customer_one).update_attribute(:profile_id, profiles(:profile_two).id)

    assert has_user_with_unauthorized_layer(customers(:customer_one))
  end

  test 'do not display warning information on new record' do
    refute has_user_with_unauthorized_layer(Customer.new)
    refute has_vehicle_with_unauthorized_router(Customer.new)
  end

  test 'customer router selected value for admin includes profile' do
    customer = customers(:customer_one)
    assert_equal "#{customer.profile_id}_#{customer.router_id}_#{customer.router_dimension}",
                 customer_router_selected_value(customer, admin: true)
  end

  test 'customer router selected value for user excludes profile' do
    customer = customers(:customer_one)
    assert_equal "#{customer.router_id}_#{customer.router_dimension}",
                 customer_router_selected_value(customer, admin: false)
  end

  test 'profile router grouped options for admin groups by profile' do
    profile = profiles(:profile_one)
    router = routers(:router_one)
    profile.routers << router unless profile.routers.include?(router)

    groups = profile_router_grouped_options_for_admin(customers(:customer_one))
    profile_group = groups.find { |name, _options| name == profile.name }

    assert profile_group
    assert profile_group[1].any? { |_label, value| value == "#{profile.id}_#{router.id}_time" }
  end
end
