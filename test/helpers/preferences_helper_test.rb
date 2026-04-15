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

  test 'current_user_planning_form_submit_enabled is false when forms.plannings is visible but not usable' do
    forms = Preferences::Catalog.default_forms.deep_dup.deep_stringify_keys
    forms['plannings'] = { 'visible' => true, 'usable' => false }
    role = Role.create!(
      reseller: @current_user.customer.reseller,
      name: "helper-planning-#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.default_operations,
      forms: Preferences::Catalog.normalize_forms(forms)
    )
    @current_user.update!(role_id: role.id)
    @current_user.reload

    assert_not current_user_planning_form_submit_enabled?(plannings(:planning_one))
    assert_not current_user_planning_form_submit_enabled?(Planning.new(customer: @current_user.customer))
  end
end
