# frozen_string_literal: true

require 'test_helper'

class PreferencesHelperTest < ActionView::TestCase
  include PreferencesHelper

  setup do
    @current_user = users(:user_one)
    @current_user.update!(role_id: nil) if @current_user.reload.role_id.present?
    @current_user.reload
  end

  # ActionView::TestCase has no Devise — stub session user like a signed-in view.
  attr_reader :current_user

  def user_signed_in?
    true
  end

  teardown do
    u = users(:user_one)
    u.update!(role_id: nil) if u.reload.role_id.present?
  end

  def assign_space!(space_key, visible:, usable:)
    spaces = Preferences::Catalog.default_spaces.deep_dup
    key = space_key.to_s
    spaces[key] = Preferences::Catalog::Spaces.default_space_entry(
      key, visible: visible, usable: usable && visible, actions_all_usable: usable && visible
    )
    role = Role.create!(
      reseller: @current_user.customer.reseller,
      name: "helper-#{key}-#{SecureRandom.hex(4)}",
      planning_toolbar: Preferences::Catalog.default_planning_toolbar,
      spaces: Preferences::Catalog.normalize_spaces(spaces)
    )
    @current_user.update!(role_id: role.id)
    @current_user.reload
  end

  test 'current_user_planning_form_submit_enabled is false when plannings edit is not usable' do
    assign_space!(:plannings, visible: true, usable: false)

    assert_not current_user_planning_form_submit_enabled?(plannings(:planning_one))
    assert_not current_user_planning_form_submit_enabled?(Planning.new(customer: @current_user.customer))
  end

  test 'current_user_destination_form_submit_enabled is false when destination edit is not usable' do
    assign_space!(:destination, visible: true, usable: false)

    assert_not current_user_destination_form_submit_enabled?(destinations(:destination_one))
    assert_not current_user_destination_form_submit_enabled?(
      Destination.new(customer: @current_user.customer)
    )
  end

  test 'current_user_customer_form_submit_enabled is false when customer edit is not usable' do
    assign_space!(:customer, visible: true, usable: false)

    assert_not current_user_customer_form_submit_enabled?(@current_user.customer)
  end

  test 'admin user bypasses customer form submit restriction via reseller admin form' do
    @current_user = users(:user_admin)
    @current_user.reload

    assert current_user_customer_form_submit_enabled?(customers(:customer_one))
  end

  test 'space helpers expose visible vs usable for sidebar show/disable' do
    assign_space!(:operations, visible: true, usable: false)

    assert current_user_space_visible?(:operations)
    assert_not current_user_space_usable?(:operations)
    assert current_user_space_action_disabled?(:operations, :export)
  end
end
