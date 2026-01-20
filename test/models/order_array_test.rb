require 'test_helper'

class OrderArrayTest < ActiveSupport::TestCase
  test 'should not save order array' do
    o = customers(:customer_one).order_arrays.build
    assert_not o.save, 'Saved without required fields'
  end

  test 'should save order array' do
    o = customers(:customer_one).order_arrays.build(name: 'plop', base_date: Date.new, length: 7)
    assert o.save
  end

  test 'should compute length of order array' do
    o = order_arrays(:order_array_one)

    o.base_date = Date.new(2000,2,1)
    o.length = 31
    assert_equal o.days, 29

    o.base_date = Date.new(2000,1,1)
    assert_equal o.days, 31

    o.length = 7
    assert_equal o.days, 7
  end

  test 'should add destination with order array' do
    o = order_arrays(:order_array_one)
    s = o.orders.size

    o.add_visit(visits(:visit_two))
    assert_equal s + o.days, o.orders.size
  end

  test 'should update orders by changing base date and length' do
    o = customers(:customer_one).order_arrays.build(name: 'plop', base_date: Date.new, length: 7) # because fixture is not correct
    o.save
    v = customers(:customer_one).destinations.collect{ |d| d.visits }.flatten.compact.size

    o.length = 31
    o.save
    assert_equal v * 31, o.orders.size

    o.base_date = Date.new(2014,11,1)
    o.save
    assert_equal v * 30, o.orders.size
  end
end
