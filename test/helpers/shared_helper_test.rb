require 'test_helper'

class SharedHelperTest < ActionView::TestCase
  include SharedHelper

  setup do
    @customer = customers(:customer_one)
    @planning = plannings(:planning_one)
    @deliverable_unit = deliverable_units(:deliverable_unit_one_one)
  end

  test "aggregate_visit_quantities with empty visits" do
    result = aggregate_visit_quantities(@customer, [])

    # Should return all deliverable units with zero quantities
    assert result.key?(@deliverable_unit.id)
    assert_equal 0, result[@deliverable_unit.id][:pickup]
    assert_equal 0, result[@deliverable_unit.id][:delivery]
    assert_equal false, result[@deliverable_unit.id][:has_pickup]
    assert_equal false, result[@deliverable_unit.id][:has_delivery]
  end

  test "aggregate_visit_quantities with nil visits" do
    result = aggregate_visit_quantities(@customer, nil)

    # Should return all deliverable units with zero quantities
    assert result.key?(@deliverable_unit.id)
    assert_equal 0, result[@deliverable_unit.id][:pickup]
    assert_equal 0, result[@deliverable_unit.id][:delivery]
    assert_equal false, result[@deliverable_unit.id][:has_pickup]
    assert_equal false, result[@deliverable_unit.id][:has_delivery]
  end

  test "aggregate_visit_quantities with visits having deliveries" do
    # Create mock visits with deliveries
    visit1 = mock('visit1')
    visit1.stubs(:is_a?).with(Visit).returns(true)
    visit1.stubs(:default_pickups).returns({})
    visit1.stubs(:default_deliveries).returns({ @deliverable_unit.id => 10.5 })

    visit2 = mock('visit2')
    visit2.stubs(:is_a?).with(Visit).returns(true)
    visit2.stubs(:default_pickups).returns({})
    visit2.stubs(:default_deliveries).returns({ @deliverable_unit.id => 5.5 })

    result = aggregate_visit_quantities(@customer, [visit1, visit2])

    # Check the specific deliverable unit we're testing
    assert result.key?(@deliverable_unit.id)
    assert_equal 0, result[@deliverable_unit.id][:pickup]
    assert_equal 16.0, result[@deliverable_unit.id][:delivery]
    assert_equal false, result[@deliverable_unit.id][:has_pickup]
    assert_equal true, result[@deliverable_unit.id][:has_delivery]
  end

  test "aggregate_visit_quantities with visits having pickups and deliveries" do
    # Create mock visits with both pickups and deliveries
    visit1 = mock('visit1')
    visit1.stubs(:is_a?).with(Visit).returns(true)
    visit1.stubs(:default_pickups).returns({ @deliverable_unit.id => 5.0 })
    visit1.stubs(:default_deliveries).returns({ @deliverable_unit.id => 10.0 })

    visit2 = mock('visit2')
    visit2.stubs(:is_a?).with(Visit).returns(true)
    visit2.stubs(:default_pickups).returns({ @deliverable_unit.id => 3.0 })
    visit2.stubs(:default_deliveries).returns({ @deliverable_unit.id => 7.0 })

    result = aggregate_visit_quantities(@customer, [visit1, visit2])

    # Check the specific deliverable unit we're testing
    assert result.key?(@deliverable_unit.id)
    assert_equal 8.0, result[@deliverable_unit.id][:pickup]
    assert_equal 17.0, result[@deliverable_unit.id][:delivery]
    assert_equal true, result[@deliverable_unit.id][:has_pickup]
    assert_equal true, result[@deliverable_unit.id][:has_delivery]
  end

  test "aggregate_visit_quantities with non-visit objects" do
    # Create mock non-visit objects
    non_visit = mock('non_visit')
    non_visit.stubs(:is_a?).with(Visit).returns(false)

    result = aggregate_visit_quantities(@customer, [non_visit])

    # Should return all deliverable units with zero quantities since non-visit objects are skipped
    assert result.key?(@deliverable_unit.id)
    assert_equal 0, result[@deliverable_unit.id][:pickup]
    assert_equal 0, result[@deliverable_unit.id][:delivery]
    assert_equal false, result[@deliverable_unit.id][:has_pickup]
    assert_equal false, result[@deliverable_unit.id][:has_delivery]
  end
end
