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

class WorkspacesActivateWebTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:account_one)
    @user = users(:user_one)
  end

  test 'web activate accepts an active membership with web access' do
    assert @user.web_channel_open?
    assert_difference 'WorkspaceSwitchEvent.count', 1 do
      result = Workspaces::Activate.call(
        account: @account,
        user_id: @user.id,
        channel: :web,
        from_user_id: @user.id
      )
      assert_equal 200, result.status
      assert_equal @user, result.user
    end
    event = WorkspaceSwitchEvent.order(:id).last
    assert_equal 'web', event.channel
    assert_equal 'ok', event.result
    assert_equal @user.id, event.from_user_id
    assert_equal @user.id, event.to_user_id
  end

  test 'web activate refuses a membership of another account without leaking existence' do
    other = users(:user_three)
    assert_difference 'WorkspaceSwitchEvent.count', 1 do
      result = Workspaces::Activate.call(account: @account, user_id: other.id, channel: :web)
      assert_equal 404, result.status
      assert_equal 'workspace_not_found', result.code
    end
  end

  test 'web activate refuses when membership has no web channel' do
    closed = Preferences::Catalog.normalize_spaces(
      Preferences::Catalog::WEB_SPACE_KEYS.index_with { |_k| { 'visible' => false, 'usable' => false } }
    )
    @user.role.update_columns(spaces: closed)
    result = Workspaces::Activate.call(account: @account, user_id: @user.id, channel: :web)
    assert_equal 403, result.status
    assert_equal 'capability_denied', result.code
  end

  test 'web activate ignores expired subscription' do
    @user.customer.update_columns(end_subscription: 1.day.ago)
    result = Workspaces::Activate.call(account: @account, user_id: @user.id, channel: :web)
    assert_equal 200, result.status
  end
end
