require 'test_helper'

class DeliverableUnitTest < ActiveSupport::TestCase
  test 'should not save' do
    unit = customers(:customer_one).deliverable_units.build(optimization_overload_multiplier: -2)
    assert_not unit.save, 'Saved with bad fields'
  end

  test 'should not save with invalid ref' do
    unit = customers(:customer_one).deliverable_units.build(ref: 'test.test')
    assert_not unit.save, 'Saved with bad ref fields'
  end

  test 'should create' do
    unit = customers(:customer_one).deliverable_units.build(label: 'plop', default_quantity: '')
    assert unit.save
    assert_nil unit.default_quantity
    assert_nil unit.localized_default_quantity
  end

  test 'should create with negative quantity' do
    unit = customers(:customer_one).deliverable_units.build(label: 'plop', default_quantity: '-1,2')
    assert unit.save
    assert_equal(-1.2, unit.default_quantity)
  end

  test 'should not create with negative capacity' do
    unit = customers(:customer_one).deliverable_units.build(label: 'plop', default_capacity: '-1,2')
    assert !unit.save
  end

  test 'should update' do
    unit = deliverable_units(:deliverable_unit_one_one)
    unit.default_capacity = ''
    assert unit.save
    assert_nil unit.default_capacity
    assert_nil unit.localized_default_capacity
  end

  test 'should update with negative quantity' do
    unit = deliverable_units(:deliverable_unit_one_one)
    unit.default_quantity = '-2,3'
    assert unit.save
    assert_equal(-2.3, unit.default_quantity)
  end

  test 'should not update with negative capacity' do
    unit = deliverable_units(:deliverable_unit_one_one)
    unit.default_capacity = '-2,3'
    assert !unit.save
  end

  test 'should save with localized attributes' do
    unit = customers(:customer_one).deliverable_units.build(default_quantity: '1,0', default_capacity: '10,0', optimization_overload_multiplier: '0,1', default_initial_load: '1,0')
    assert unit.save
    assert_equal 1, unit.default_quantity
    assert_equal 1, unit.default_initial_load
  end

  test 'should validate default_initial_load is greater than or equal to 0' do
    deliverable_unit = deliverable_units(:deliverable_unit_one_one)
    deliverable_unit.default_initial_load = -1
    assert_not deliverable_unit.valid?
  end

  test 'should allow nil default_initial_load' do
    deliverable_unit = deliverable_units(:deliverable_unit_one_one)
    deliverable_unit.default_initial_load = nil
    assert deliverable_unit.valid?
  end
end
