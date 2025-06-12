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
    unit = customers(:customer_one).deliverable_units.build(label: 'plop', default_delivery: '')
    assert unit.save
    assert_nil unit.default_pickup
    assert_nil unit.localized_default_pickup
  end

  test 'should create with pickup and delivery' do
    unit = customers(:customer_one).deliverable_units.build(label: 'plop', default_pickup: '1,2', default_delivery: '2,1')
    assert unit.save
    assert_equal(1.2, unit.default_pickup)
    assert_equal(2.1, unit.default_delivery)
  end

  test 'should not create with negative pickup' do
    unit = customers(:customer_one).deliverable_units.build(label: 'plop', default_pickup: '-1,2')
    assert !unit.save
  end

  test 'should not create with negative delivery' do
    unit = customers(:customer_one).deliverable_units.build(label: 'plop', default_delivery: '-1,2')
    assert !unit.save
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

  test 'should update with negative delivery' do
    unit = deliverable_units(:deliverable_unit_one_one)
    unit.default_delivery = '2,3'
    assert unit.save
    assert_equal(2.3, unit.default_delivery)
  end

  test 'should not update with negative delivery' do
    unit = deliverable_units(:deliverable_unit_one_one)
    unit.default_delivery = '-2,3'
    assert !unit.save
  end

  test 'should update with negative pickup' do
    unit = deliverable_units(:deliverable_unit_one_one)
    unit.default_pickup = '2,3'
    assert unit.save
    assert_equal(2.3, unit.default_pickup)
  end

  test 'should not update with negative pickup' do
    unit = deliverable_units(:deliverable_unit_one_one)
    unit.default_pickup = '-2,3'
    assert !unit.save
  end

  test 'should not update with negative capacity' do
    unit = deliverable_units(:deliverable_unit_one_one)
    unit.default_capacity = '-2,3'
    assert !unit.save
  end

  test 'should save with localized attributes' do
    unit = customers(:customer_one).deliverable_units.build(default_pickup: '2,0', default_delivery: '1,0', default_capacity: '10,0', optimization_overload_multiplier: '0,1')
    assert unit.save
    assert_equal 2, unit.default_pickup
    assert_equal 1, unit.default_delivery
  end
end
