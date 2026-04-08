# frozen_string_literal: true

require 'test_helper'

# Grape v01 vehicles uses authorize!(:create|:update, VehicleUsage).
class AbilityVehicleUsageApiTest < ActiveSupport::TestCase
  test 'customer user without role can create VehicleUsage (catalog form defaults)' do
    user = users(:user_one)
    assert_nil user.role_id

    ability = Ability.new(user)
    assert ability.can?(:create, VehicleUsage), 'customer API vehicle create'
    assert ability.can?(:update, VehicleUsage), 'customer API vehicle update'
  end

  test 'admin can create VehicleUsage for reseller fleet' do
    ability = Ability.new(users(:user_admin))
    assert ability.can?(:create, VehicleUsage), 'admin API vehicle create'
  end
end
