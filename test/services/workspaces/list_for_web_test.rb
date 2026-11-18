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

class WorkspacesListForWebTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:account_one)
    @user = users(:user_one)
  end

  test 'web list includes active memberships with web access' do
    list = Workspaces::ListFor.call(@account, channel: :web)
    assert_includes list.map(&:id), @user.id
  end

  test 'web list excludes suspended memberships' do
    @user.update_columns(status: 'suspended')
    list = Workspaces::ListFor.call(@account, channel: :web)
    assert_not_includes list.map(&:id), @user.id
  end

  test 'web list excludes active memberships without a role' do
    assert @user.web_channel_open?
    @user.update_columns(role_id: nil)
    assert @user.reload.web_channel_open?, 'blank role still signs in'
    assert_not Workspaces::ListFor.web_workspace?(@user)
    list = Workspaces::ListFor.call(@account, channel: :web)
    assert_not_includes list.map(&:id), @user.id
  end

  test 'reseller_web lists active web memberships for the admin reseller' do
    admin = users(:user_admin)
    list = Workspaces::ListFor.reseller_web(admin)
    assert list.any?
    assert list.all? { |user| user.customer.reseller_id == admin.reseller_id }
    assert_includes list.map(&:id), @user.id
  end

  test 'reseller_web preloads accounts so web_channel_open? does not N+1' do
    admin = users(:user_admin)
    list = Workspaces::ListFor.reseller_web(admin)
    assert list.any?
    assert list.all? { |user| user.association(:account).loaded? }
  end

  test 'mobile_only lists mobile workspaces without web access' do
    @user.customer.update!(operations_mobile: true, devices: { deliver: { enable: true } })
    closed = Preferences::Catalog.normalize_spaces(
      Preferences::Catalog::WEB_SPACE_KEYS.index_with { |_k| { 'visible' => false, 'usable' => false } }.merge(
        'operations_mobile' => { 'visible' => true, 'usable' => true }
      )
    )
    role = Role.create!(
      reseller: resellers(:reseller_one),
      name: "Mobile only #{SecureRandom.hex(4)}",
      spaces: closed,
      operations_mobile: OperationsMobile.driver_default
    )
    @user.update!(role: role)

    assert Workspaces::ListFor.mobile_workspace?(@user)
    assert_not Workspaces::ListFor.web_workspace?(@user)
    only = Workspaces::ListFor.mobile_only(@account)
    assert_includes only.map(&:id), @user.id
  end
end
