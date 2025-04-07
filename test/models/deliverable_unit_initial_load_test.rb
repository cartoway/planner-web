require 'test_helper'

class DeliverableUnitInitialLoadTest < ActiveSupport::TestCase
  test 'creates empty hash when nil is provided' do
    initial_loads = DeliverableUnitInitialLoad.new(nil)
    assert_equal({}, initial_loads.to_h)
  end

  test 'converts string values to floats' do
    initial_loads = DeliverableUnitInitialLoad.new({ '1' => '10.5', '2' => '20.0' })
    assert_equal({ 1 => 10.5, 2 => 20.0 }, initial_loads.to_h)
  end

  test 'skips empty values' do
    initial_loads = DeliverableUnitInitialLoad.new({ '1' => '10.5', '2' => '' })
    assert_equal({ 1 => 10.5 }, initial_loads.to_h)
  end

  test 'keeps invalid values as is for model validation' do
    initial_loads = DeliverableUnitInitialLoad.new({ '1' => 'invalid' })
    assert_equal({ 1 => 'invalid' }, initial_loads.to_h)
  end
end
