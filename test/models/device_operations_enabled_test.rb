# frozen_string_literal: true

require 'test_helper'

class DeviceOperationsEnabledTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @previous_devices = @customer.devices
  end

  teardown do
    @customer.update!(devices: @previous_devices)
  end

  test 'operations are enabled when Cartoway Deliver is active' do
    @customer.update!(devices: { deliver: { enable: true } })
    assert @customer.device.definitions[:deliver][:has_operations]
    assert @customer.device.operations_enabled?
    assert Ability.new(users(:user_one)).can?(:manage, Operation)
  end

  test 'operations are disabled without a has_operations device' do
    @customer.update!(devices: { tomtom: { enable: true, account: 'a', user: 'u', password: 'p' } })
    refute @customer.device.definitions[:tomtom][:has_operations]
    refute @customer.device.operations_enabled?
    refute Ability.new(users(:user_one)).can?(:manage, Operation)
  end
end
