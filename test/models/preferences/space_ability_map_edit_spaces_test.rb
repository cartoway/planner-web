# frozen_string_literal: true

require 'test_helper'

class PreferencesSpaceAbilityMapEditSpacesTest < ActiveSupport::TestCase
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

  def assign_role_with_space!(user, space_key, visible:, usable:)
    spaces = Preferences::Catalog.default_spaces.deep_dup
    key = space_key.to_s
    spaces[key] = Preferences::Catalog::Spaces.default_space_entry(
      key, visible: visible, usable: usable && visible, actions_all_usable: usable && visible
    )
    role = Role.create!(
      reseller: user.customer.reseller,
      name: "space-ability-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces)
    )
    user.update!(role_id: role.id)
    user.reload
    role
  end

  test 'customer can create destination when destination space allows edit' do
    ability = Ability.new(@user)
    assert ability.can?(:create, Destination)
  end

  test 'customer cannot create destination when destination edit is not usable' do
    assign_role_with_space!(@user, :destination, visible: true, usable: false)

    ability = Ability.new(@user)
    assert ability.cannot?(:create, Destination)
  end

  test 'customer cannot update destination when destination edit is not usable' do
    assign_role_with_space!(@user, :destination, visible: true, usable: false)

    ability = Ability.new(@user)
    assert ability.cannot?(:update, @destination)
    assert ability.cannot?(:destroy, @destination)
  end

  test 'customer can open vehicle_usage edit in read-only when visible but not usable' do
    assign_role_with_space!(@user, :vehicle_usages, visible: true, usable: false)

    ability = Ability.new(@user)
    assert ability.can?(:edit, @vehicle_usage)
    assert ability.cannot?(:update, @vehicle_usage)
    assert ability.cannot?(:toggle, @vehicle_usage)
  end

  test 'customer cannot update vehicle_usage_set when vehicle configurations are not usable' do
    assign_role_with_space!(@user, :vehicle_usages, visible: true, usable: false)

    ability = Ability.new(@user)
    assert ability.cannot?(:update, vehicle_usage_sets(:vehicle_usage_set_one))
    assert ability.cannot?(:destroy, vehicle_usage_sets(:vehicle_usage_set_one))
  end

  test 'customer can open planning edit in read-only when plannings visible but not usable' do
    assign_role_with_space!(@user, :plannings, visible: true, usable: false)

    ability = Ability.new(@user)
    planning = plannings(:planning_one)
    assert_equal @user.customer_id, planning.customer_id
    assert ability.can?(:edit, planning)
    assert ability.cannot?(:update, planning)
  end

  test 'customer cannot update store when stores edit is not usable' do
    assign_role_with_space!(@user, :stores, visible: true, usable: false)

    ability = Ability.new(@user)
    assert ability.cannot?(:update, stores(:store_one))
  end

  test 'customer can open own customer edit in read-only when customer space is visible but not usable' do
    assign_role_with_space!(@user, :customer, visible: true, usable: false)

    ability = Ability.new(@user)
    assert ability.can?(:edit, @user.customer)
    assert ability.cannot?(:update, @user.customer)
  end

  test 'customer cannot open customer edit when customer space is hidden' do
    assign_role_with_space!(@user, :customer, visible: false, usable: false)

    ability = Ability.new(@user)
    assert ability.cannot?(:edit, @user.customer)
  end

  test 'customer cannot open planning edit when plannings space is hidden' do
    assign_role_with_space!(@user, :plannings, visible: false, usable: false)

    ability = Ability.new(@user)
    assert ability.cannot?(:edit, plannings(:planning_one))
  end

  test 'hidden vehicle_usages denies delete_vehicle on own customer even when customer is manageable' do
    assign_role_with_space!(@user, :vehicle_usages, visible: false, usable: false)

    ability = Class.new { include CanCan::Ability }.new
    ability.can :manage, Customer, id: @user.customer.id
    Preferences::SpaceAbilityMap.send(:apply_vehicle_configuration_hidden_gate!, ability, @user)

    assert ability.cannot?(:delete_vehicle, @user.customer)
  end

  test 'hidden tags denies listing and showing tag records' do
    assign_role_with_space!(@user, :tags, visible: false, usable: false)

    ability = Ability.new(@user)
    tag = tags(:tag_one)
    assert_equal @user.customer_id, tag.customer_id
    assert ability.cannot?(:index, Tag)
    assert ability.cannot?(:show, tag)
  end

  test 'tags visible but not usable denies create update destroy on Tag' do
    assign_role_with_space!(@user, :tags, visible: true, usable: false)

    ability = Ability.new(@user)
    tag = tags(:tag_one)
    assert ability.cannot?(:create, Tag)
    assert ability.cannot?(:new, Tag)
    assert ability.cannot?(:update, tag)
    assert ability.cannot?(:destroy, tag)
  end

  test 'customer cannot create deliverable unit when deliverable_units edit is not usable' do
    assign_role_with_space!(@user, :deliverable_units, visible: true, usable: false)

    ability = Ability.new(@user)
    assert ability.cannot?(:create, DeliverableUnit)
    assert ability.cannot?(:destroy, deliverable_units(:deliverable_unit_one_one))
  end

  test 'hidden custom_attributes denies listing custom attribute records' do
    assign_role_with_space!(@user, :custom_attributes, visible: false, usable: false)

    ability = Ability.new(@user)
    assert ability.cannot?(:index, CustomAttribute)
    assert ability.cannot?(:show, custom_attributes(:custom_attribute_one))
  end
end
