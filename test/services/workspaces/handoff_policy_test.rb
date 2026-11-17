# frozen_string_literal: true

# Copyright © Cartoway, 2026
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

require 'test_helper'

class WorkspacesHandoffPolicyTest < ActiveSupport::TestCase
  test 'authorize allows same-account switch without impersonator' do
    user = users(:user_one)
    decision = Workspaces::HandoffPolicy.authorize(actor: user, target: user, reseller_admin: nil)
    assert decision.allowed
    assert_nil decision.impersonator
  end

  test 'authorize refuses inactive target' do
    admin = users(:user_admin)
    target = users(:user_one)
    target.update_columns(status: 'suspended')
    decision = Workspaces::HandoffPolicy.authorize(actor: admin, target: target, reseller_admin: admin)
    assert_not decision.allowed
  end

  test 'authorize keeps reseller admin when switching same-account during login-as' do
    admin = users(:user_admin)
    actor = users(:user_one)
    peer = actor.account.users.create!(
      customer: customers(:customer_one_other),
      email: actor.account.email,
      status: 'active',
      relationship: 'employee',
      role: roles(:role_catalog),
      layer: layers(:layer_one),
      api_key: SecureRandom.hex(8)
    )

    decision = Workspaces::HandoffPolicy.authorize(
      actor: actor,
      target: peer,
      reseller_admin: admin
    )
    assert decision.allowed
    assert_equal admin, decision.impersonator
  end

  test 'authorize sets impersonator for reseller admin cross-account' do
    admin = users(:user_admin)
    target = users(:user_one)
    decision = Workspaces::HandoffPolicy.authorize(actor: admin, target: target, reseller_admin: admin)
    assert decision.allowed
    assert_equal admin, decision.impersonator
  end

  test 'claim cold with token impersonator does not adopt admin' do
    target = users(:user_one)
    admin = users(:user_admin)
    decision = Workspaces::HandoffPolicy.claim(
      actor: nil,
      target: target,
      token_impersonator: admin
    )
    assert decision.allowed
    assert_nil decision.impersonator
  end

  test 'claim refuses signed-in non-admin for login-as token' do
    admin = users(:user_admin)
    actor = users(:user_one)
    target = users(:user_two)
    decision = Workspaces::HandoffPolicy.claim(
      actor: actor,
      target: target,
      token_impersonator: admin
    )
    assert_not decision.allowed
  end

  test 'claim refuses signed-in non-admin for other-account target' do
    actor = users(:user_one)
    target = users(:user_two)
    decision = Workspaces::HandoffPolicy.claim(
      actor: actor,
      target: target,
      token_impersonator: nil
    )
    assert_not decision.allowed
  end

  test 'claim allows signed-in non-admin same-account target' do
    actor = users(:user_one)
    peer = actor.account.users.create!(
      customer: customers(:customer_one_other),
      email: actor.account.email,
      status: 'active',
      relationship: 'employee',
      role: roles(:role_catalog),
      layer: layers(:layer_one),
      api_key: SecureRandom.hex(8)
    )
    decision = Workspaces::HandoffPolicy.claim(
      actor: actor,
      target: peer,
      token_impersonator: nil
    )
    assert decision.allowed
    assert_nil decision.impersonator
  end

  test 'claim signed-in admin adopts self as impersonator' do
    admin = users(:user_admin)
    target = users(:user_one)
    decision = Workspaces::HandoffPolicy.claim(
      actor: admin,
      target: target,
      token_impersonator: admin
    )
    assert decision.allowed
    assert_equal admin, decision.impersonator
  end

  test 'claim continues login-as when true_user admin matches token' do
    admin = users(:user_admin)
    target = users(:user_two)
    decision = Workspaces::HandoffPolicy.claim(
      actor: admin,
      target: target,
      token_impersonator: admin,
      current_impersonator: admin
    )
    assert decision.allowed
    assert_equal admin, decision.impersonator
  end

end
