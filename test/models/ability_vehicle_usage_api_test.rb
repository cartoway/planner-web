# frozen_string_literal: true

require 'test_helper'

# Grape v01 vehicles uses authorize!(:create|:update, VehicleUsage).
class AbilityVehicleUsageApiTest < ActiveSupport::TestCase
  setup do
    @user = users(:user_one)
  end

  teardown do
    u = users(:user_one)
    u.update!(role_id: nil) if u.reload.role_id.present?
  end

  test 'customer user without role cannot mutate VehicleUsage when no_role restricts forms.vehicle_usages' do
    prev = Rails.application.config.default_permissions_config
    cfg = prev.deep_dup.deep_stringify_keys
    no_role = (cfg['no_role'] || {}).deep_dup
    no_role['forms'] = (no_role['forms'] || {}).merge('vehicle_usages' => { 'visible' => true, 'usable' => false })
    cfg['no_role'] = no_role
    Rails.application.config.default_permissions_config = cfg

    @user.reload
    assert_nil @user.role_id

    ability = Ability.new(@user)
    assert ability.cannot?(:create, VehicleUsage)
    assert ability.cannot?(:update, VehicleUsage)
  ensure
    Rails.application.config.default_permissions_config = prev if prev
  end

  test 'customer user with role allowing vehicle_usages can create and update VehicleUsage (API)' do
    role = Role.create!(
      reseller: @user.customer.reseller,
      name: "api-vu-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.default_forms
    )
    @user.update!(role_id: role.id)

    ability = Ability.new(@user.reload)
    assert ability.can?(:create, VehicleUsage), 'customer API vehicle create'
    assert ability.can?(:update, VehicleUsage), 'customer API vehicle update'
  end

  test 'admin can create VehicleUsage for reseller fleet' do
    ability = Ability.new(users(:user_admin))
    assert ability.can?(:create, VehicleUsage), 'admin API vehicle create'
  end
end
