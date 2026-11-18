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

class WorkspacesHelperTest < ActionView::TestCase
  test 'workspace_chip_customer_groups keeps order and groups by customer' do
    a = users(:user_one)
    other_customer = customers(:customer_one_other)
    peer_same = a.account.users.build(
      customer: a.customer,
      email: 'peer-same-customer@example.com',
      status: 'active',
      relationship: 'employee',
      role: a.role,
      layer: a.layer,
      api_key: SecureRandom.hex(8)
    )
    alone = a.account.users.build(
      customer: other_customer,
      email: 'alone-other-customer@example.com',
      status: 'active',
      relationship: 'employee',
      role: roles(:role_catalog),
      layer: a.layer,
      api_key: SecureRandom.hex(8)
    )
    list = [a, peer_same, alone]
    groups = workspace_chip_customer_groups(list)

    assert_equal 2, groups.size
    assert_equal a.customer, groups[0][0]
    assert_equal [a, peer_same], groups[0][1]
    assert_equal other_customer, groups[1][0]
    assert_equal [alone], groups[1][1]
  end

  test 'workspace_chip_user_label prefers email' do
    user = users(:user_one)
    assert_equal user.email, workspace_chip_user_label(user)
  end
end
