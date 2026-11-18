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

class AccountMembershipTest < ActiveSupport::TestCase
  test 'two memberships share one account and one password' do
    account = accounts(:account_one)
    digest = account.encrypted_password
    other = customers(:customer_one_other)
    user = account.users.create!(
      customer: other,
      email: account.email,
      status: 'active',
      relationship: 'employee'
    )

    assert_equal account, user.account
    assert_equal digest, account.reload.encrypted_password
    assert user.valid_password?('123456789')
    assert_equal 2, account.users.where(status: 'active').count
  end

  test 'updating membership email persists on the shared account' do
    user = users(:user_two)
    user.update!(email: 'synced-account@example.com')

    assert_equal 'synced-account@example.com', user.reload.email
    assert_equal 'synced-account@example.com', user.account.reload.email
  end
end
