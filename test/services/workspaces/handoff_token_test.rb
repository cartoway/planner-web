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

class WorkspacesHandoffTokenTest < ActiveSupport::TestCase
  test 'parse round-trips user and optional impersonator without consuming' do
    user = users(:user_one)
    admin = users(:user_admin)
    token = Workspaces::HandoffToken.generate(user: user, impersonator: admin)
    result = Workspaces::HandoffToken.parse(token)

    assert_equal user, result.user
    assert_equal admin, result.impersonator
    assert result.jti.present?
    assert_equal user, Workspaces::HandoffToken.parse(token).user, 'parse must not burn the jti'
  end

  test 'consume is one-shot on planner_cache' do
    user = users(:user_one)
    token = Workspaces::HandoffToken.generate(user: user)
    result = Workspaces::HandoffToken.parse(token)

    assert Workspaces::HandoffToken.consume!(result.jti)
    assert_not Workspaces::HandoffToken.consume!(result.jti)
  end

  test 'rejects tampered or blank tokens' do
    assert_nil Workspaces::HandoffToken.parse(nil)
    assert_nil Workspaces::HandoffToken.parse('nope')
    token = Workspaces::HandoffToken.generate(user: users(:user_one))
    assert_nil Workspaces::HandoffToken.parse(token.reverse)
  end
end
