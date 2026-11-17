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

class CustomerDefaultDriverRoleTest < ActiveSupport::TestCase
  test 'effective_default_driver_role uses customer override then reseller default' do
    reseller = resellers(:reseller_one)
    driver_default = Role.create_default_driver_role_for!(reseller)
    reseller.update_column(:default_driver_role_id, driver_default.id)

    customer = customers(:customer_one)
    customer.update!(default_driver_role_id: nil)
    assert_equal driver_default, customer.effective_default_driver_role

    override = Role.create!(
      reseller: reseller,
      name: "Custom driver #{SecureRandom.hex(3)}",
      spaces: Role.default_driver_role_spaces_json,
      operations_mobile: OperationsMobile.driver_default
    )
    customer.update!(default_driver_role: override)
    assert_equal override, customer.effective_default_driver_role
  end
end
