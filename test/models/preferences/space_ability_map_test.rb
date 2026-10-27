# frozen_string_literal: true

require 'test_helper'

class PreferencesSpaceAbilityMapTest < ActiveSupport::TestCase
  setup do
    @user = users(:user_one)
    @customer = @user.customer
    @previous_devices = @customer.devices
    @customer.update!(devices: { deliver: { enable: true } })
  end

  teardown do
    @customer.update!(devices: @previous_devices)
    u = users(:user_one)
    u.update!(role_id: nil) if u.reload.role_id.present?
  end

  def assign_role_with_spaces!(user, spaces_hash)
    role = Role.create!(
      reseller: user.customer.reseller,
      name: "space-ability-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces_hash)
    )
    user.update!(role_id: role.id)
    user.reload
    role
  end

  test 'hidden operations space denies listing and managing operations' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['operations'] = {
      'visible' => false,
      'usable' => false,
      'actions' => spaces['operations']['actions']
    }

    assign_role_with_spaces!(@user, spaces)

    ability = Ability.new(@user)
    assert ability.cannot?(:index, Operation)
    assert ability.cannot?(:show, Operation)
    assert ability.cannot?(:manage, Operation)
  end

  test 'disabled operations space denies listing and managing operations' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    spaces['operations'] = {
      'visible' => true,
      'usable' => false,
      'actions' => spaces['operations']['actions']
    }

    assign_role_with_spaces!(@user, spaces)

    ability = Ability.new(@user)
    assert @user.space_visible?(:operations)
    assert_not @user.space_usable?(:operations)
    assert ability.cannot?(:index, Operation)
    assert ability.cannot?(:show, Operation)
    assert ability.cannot?(:manage, Operation)
  end

  test 'operations space without sync action denies create and planning publish' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    controls = spaces['operations']['actions']['segment_controls']
    controls['sync'] = { 'visible' => true, 'usable' => false }

    assign_role_with_spaces!(@user, spaces)

    ability = Ability.new(@user)
    assert ability.can?(:index, Operation)
    assert ability.cannot?(:create, Operation)
    assert ability.cannot?(:publish_operation, plannings(:planning_one))
  end

  test 'operations space without transmit action denies transmit abilities' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    controls = spaces['operations']['actions']['segment_controls']
    controls['transmit'] = { 'visible' => true, 'usable' => false }

    assign_role_with_spaces!(@user, spaces)

    ability = Ability.new(@user)
    assert ability.cannot?(:transmit, Operation)
    assert ability.cannot?(:transmit_destinations, Operation)
  end

  test 'operations space without destroy action denies destroy on Operation' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    controls = spaces['operations']['actions']['segment_controls']
    controls['destroy'] = { 'visible' => true, 'usable' => false }

    assign_role_with_spaces!(@user, spaces)

    ability = Ability.new(@user)
    assert ability.cannot?(:destroy, Operation)
  end

  test 'operations space without export action denies export on Operation' do
    spaces = Preferences::Catalog.default_spaces.deep_dup
    controls = spaces['operations']['actions']['segment_controls']
    controls['export'] = { 'visible' => true, 'usable' => false }

    assign_role_with_spaces!(@user, spaces)

    ability = Ability.new(@user)
    assert ability.cannot?(:export, Operation)
  end
end
