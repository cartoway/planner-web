# frozen_string_literal: true

# Copyright © Cartoway
require 'test_helper'

class Workspaces::EffectiveUserTest < ActiveSupport::TestCase
  test 'admin login-as session resolves to the workspace membership with a customer' do
    admin = users(:user_admin)
    member = users(:user_one)
    session = { WorkspaceSession::WORKSPACE_USER_SESSION => member.id }

    effective = Workspaces::EffectiveUser.call(admin, session)
    assert_equal member, effective
    assert effective.customer.present?
  end

  test 'admin without workspace session stays the admin (no customer)' do
    admin = users(:user_admin)
    effective = Workspaces::EffectiveUser.call(admin, {})
    assert_equal admin, effective
    assert_nil effective.customer
  end

  test 'planted workspace id for non-admin is ignored' do
    member = users(:user_one)
    peer = users(:user_two)
    session = { WorkspaceSession::WORKSPACE_USER_SESSION => peer.id }

    assert_equal member, Workspaces::EffectiveUser.call(member, session)
  end
end
