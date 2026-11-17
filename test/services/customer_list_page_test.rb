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

class CustomerListPageTest < ActiveSupport::TestCase
  test 'returns 1-based page for a customer in name order' do
    reseller = resellers(:reseller_one)
    ids = reseller.customers.order(:name, :id).pluck(:id)
    skip 'need at least 2 customers' if ids.size < 2

    per_page = 1
    second_id = ids[1]
    assert_equal 2, CustomerListPage.for(reseller: reseller, customer_id: second_id, per_page: per_page)
    assert_equal 1, CustomerListPage.for(reseller: reseller, customer_id: ids[0], per_page: per_page)
  end

  test 'returns nil for unknown customer' do
    reseller = resellers(:reseller_one)
    assert_nil CustomerListPage.for(reseller: reseller, customer_id: 0, per_page: 25)
  end
end
