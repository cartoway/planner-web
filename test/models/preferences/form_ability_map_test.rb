# frozen_string_literal: true

require 'test_helper'

class PreferencesFormAbilityMapTest < ActiveSupport::TestCase
  setup do
    @user = users(:user_one)
    @destination = destinations(:destination_one)
    @vehicle_usage = vehicle_usages(:vehicle_usage_one_one)
  end

  teardown do
    # Tests assign a role to user_one; reset so other tests see the fixture user.
    u = users(:user_one)
    u.update!(role_id: nil) if u.reload.role_id.present?
  end

  def assign_role_with_forms!(user, forms_hash)
    role = Role.create!(
      reseller: user.customer.reseller,
      name: "form-ability-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: forms_hash
    )
    user.update!(role_id: role.id)
    user.reload
    role
  end

  test 'customer can create destination when forms.destinations allows create' do
    ability = Ability.new(@user)
    assert ability.can?(:create, Destination)
  end

  test 'customer cannot create destination when forms.destinations is not mutable' do
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['destinations'] = { 'visible' => true, 'usable' => false }

    assign_role_with_forms!(@user, Preferences::Catalog.normalize_forms(forms))

    ability = Ability.new(@user)
    assert ability.cannot?(:create, Destination)
  end

  test 'customer cannot update destination when forms.destinations disallows update' do
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['destinations'] = { 'visible' => true, 'usable' => false }

    assign_role_with_forms!(@user, Preferences::Catalog.normalize_forms(forms))

    ability = Ability.new(@user)
    assert ability.cannot?(:update, @destination)
  end

  test 'customer can open vehicle_usage edit in read-only when visible but not usable' do
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['vehicle_usages'] = { 'visible' => true, 'usable' => false }

    assign_role_with_forms!(@user, Preferences::Catalog.normalize_forms(forms))

    ability = Ability.new(@user)
    assert ability.can?(:edit, @vehicle_usage)
    assert ability.cannot?(:update, @vehicle_usage)
    assert ability.cannot?(:toggle, @vehicle_usage)
  end

  test 'customer can open planning edit in read-only when plannings visible but not usable' do
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['plannings'] = { 'visible' => true, 'usable' => false }

    assign_role_with_forms!(@user, Preferences::Catalog.normalize_forms(forms))

    ability = Ability.new(@user)
    planning = plannings(:planning_one)
    assert_equal @user.customer_id, planning.customer_id
    assert ability.can?(:edit, planning)
    assert ability.cannot?(:update, planning)
  end

  test 'customer cannot open planning edit when plannings form is hidden' do
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['plannings'] = { 'visible' => false, 'usable' => false }

    assign_role_with_forms!(@user, Preferences::Catalog.normalize_forms(forms))

    ability = Ability.new(@user)
    assert ability.cannot?(:edit, plannings(:planning_one))
  end

  test 'hidden vehicle_usages denies delete_vehicle on own customer even when customer is manageable' do
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['vehicle_usages'] = { 'visible' => false, 'usable' => false }

    assign_role_with_forms!(@user, Preferences::Catalog.normalize_forms(forms))

    ability = Class.new { include CanCan::Ability }.new
    ability.can :manage, Customer, id: @user.customer.id
    Preferences::FormAbilityMap.send(:apply_vehicle_configuration_hidden_gate!, ability, @user)

    assert ability.cannot?(:delete_vehicle, @user.customer)
  end
end
