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

class MembershipWithoutRoleTest < ActiveSupport::TestCase
  setup do
    @user = users(:user_one)
    @user.update!(role_id: nil)
  end

  test 'web sign-in stays open and every planner space is closed' do
    assert @user.web_channel_open?
    assert @user.active_for_authentication?
    Preferences::Catalog::SPACE_KEYS.each do |key|
      refute @user.space_visible?(key), key
      refute @user.space_usable?(key), key
    end
    assert_equal OperationsMobile.none, @user.mobile_capabilities
  end

  test 'a role with no visible space still refuses the web channel' do
    role = Role.create!(
      reseller: @user.customer.reseller,
      name: "Closed #{SecureRandom.hex(4)}",
      spaces: Preferences::Catalog.closed_spaces
    )
    @user.update!(role: role)
    refute @user.web_channel_open?
    refute @user.active_for_authentication?
  end

  test 'a reseller admin without a role keeps admin rights' do
    admin = users(:user_admin)
    admin.update!(role_id: nil)
    assert admin.web_channel_open?
    assert admin.space_visible?(:plannings)
    assert admin.space_usable?(:destination)
  end
end
