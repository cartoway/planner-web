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

class AccountSummaryTest < ActiveSupport::TestCase
  test 'capabilities.access follows space_usable operations_mobile' do
    user = users(:user_one)
    role = Role.create!(
      reseller: resellers(:reseller_one),
      name: "Driver summary #{SecureRandom.hex(4)}",
      spaces: Preferences::Catalog.normalize_spaces(
        'operations_mobile' => { 'visible' => true, 'usable' => true }
      ),
      operations_mobile: OperationsMobile.driver_default
    )
    user.update!(role: role)

    body = AccountSummary.for(user)
    assert_equal '3.1.0', body[:contract_version]
    assert_equal 'usable', body.dig(:capabilities, 'access')
    assert_equal 'usable', body.dig(:capabilities, 'capabilities', 'routes.read_assigned')

    closed = Preferences::Catalog.normalize_spaces(
      'operations_mobile' => { 'visible' => true, 'usable' => false }
    )
    role.update!(spaces: closed)
    user.reload

    body = AccountSummary.for(user)
    assert_equal 'none', body.dig(:capabilities, 'access')
    refute body.dig(:capabilities, 'capabilities')&.key?('routes.read_assigned')
  end
end
