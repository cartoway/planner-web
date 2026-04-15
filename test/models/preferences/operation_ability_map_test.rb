# frozen_string_literal: true

require 'test_helper'

class PreferencesOperationAbilityMapTest < ActiveSupport::TestCase
  setup do
    @user = users(:user_one)
    @planning = plannings(:planning_one)
    @route = routes(:route_one_one)
    @vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
  end

  def assign_role_with_operations!(user, operations_hash)
    role = Role.create!(
      reseller: user.customer.reseller,
      name: "ability-map-#{SecureRandom.hex(4)}",
      operations: operations_hash,
      forms: Preferences::Catalog.default_forms
    )
    user.update!(role_id: role.id)
    user.reload
    role
  end

  teardown do
    u = users(:user_one)
    u.update!(role_id: nil) if u.reload.role_id.present?
  end

  test 'customer can optimize planning when toolbar segment is usable' do
    ability = Ability.new(@user)
    assert ability.can?(:optimize, @planning)
    assert ability.can?(:optimize_route, @planning)
  end

  test 'customer cannot optimize when planning optimize segment is not usable' do
    ops = Preferences::Catalog.default_operations.deep_dup
    ops['planning'] = (ops['planning'] || {}).stringify_keys
    seg = ops['planning']['segments'] || Preferences::Catalog::OPERATION_GROUPS_PLANNING
    ops['planning']['segments'] = seg
    controls = (ops['planning']['segment_controls'] || {}).stringify_keys
    controls['optimize'] = { 'visible' => true, 'usable' => false }
    ops['planning']['segment_controls'] = controls

    assign_role_with_operations!(@user, ops)

    ability = Ability.new(@user)
    assert ability.cannot?(:optimize, @planning)
    assert ability.cannot?(:optimize_route, @planning)
  end

  test 'customer can optimize route when route toolbar optimize segment is usable' do
    ability = Ability.new(@user)
    assert ability.can?(:optimize, @route)
  end

  test 'customer cannot optimize route when route optimize segment is not usable' do
    ops = Preferences::Catalog.default_operations.deep_dup
    ops['route'] = (ops['route'] || {}).stringify_keys
    seg = ops['route']['segments'] || Preferences::Catalog::OPERATION_GROUPS_ROUTE
    ops['route']['segments'] = seg
    controls = (ops['route']['segment_controls'] || {}).stringify_keys
    controls['optimize'] = { 'visible' => true, 'usable' => false }
    ops['route']['segment_controls'] = controls

    assign_role_with_operations!(@user, ops)

    ability = Ability.new(@user)
    assert ability.cannot?(:optimize, @route)
  end

  test 'customer cannot apply_zonings when zoning segment is not usable' do
    ops = Preferences::Catalog.default_operations.deep_dup
    ops['planning'] = (ops['planning'] || {}).stringify_keys
    seg = ops['planning']['segments'] || Preferences::Catalog::OPERATION_GROUPS_PLANNING
    ops['planning']['segments'] = seg
    controls = (ops['planning']['segment_controls'] || {}).stringify_keys
    controls['zoning'] = { 'visible' => true, 'usable' => false }
    ops['planning']['segment_controls'] = controls

    assign_role_with_operations!(@user, ops)

    ability = Ability.new(@user)
    assert ability.cannot?(:apply_zonings, @planning)
  end

  test 'customer can still edit vehicle_usage when route vehicle_usage toolbar tool is not usable' do
    # Route toolbar vehicle_usage only affects the selector on the plan, not the vehicle_usage CRUD form.
    ops = Preferences::Catalog.default_operations.deep_dup
    ops['route'] = (ops['route'] || {}).stringify_keys
    seg = ops['route']['segments'] || Preferences::Catalog::OPERATION_GROUPS_ROUTE
    ops['route']['segments'] = seg
    controls = (ops['route']['segment_controls'] || {}).stringify_keys
    controls['vehicle_usage'] = { 'visible' => true, 'usable' => false }
    ops['route']['segment_controls'] = controls

    assign_role_with_operations!(@user, ops)

    ability = Ability.new(@user)
    assert ability.can?(:edit, @vehicle_usage)
    assert ability.can?(:update, @vehicle_usage)
    assert ability.can?(:toggle, @vehicle_usage)
  end
end
