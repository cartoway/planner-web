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

class Admin::ToolsControllerTest < ActionController::TestCase
  setup do
    @request.host = resellers(:reseller_one).host.to_s
    sign_in users(:user_admin), scope: :user
  end

  test 'v2 admin menu exposes jobs and performances and tools render in the v2 layout' do
    enable_layout_v2!(users(:user_admin))

    get :delayed_job
    assert_response :success
    assert_template layout: 'v2/layouts/application'
    assert_select 'iframe#delayed_job_iframe[src=?]', delayed_job_path
    assert_select %(a[href="#{admin_tools_delayed_job_path}"][data-turbo-frame="main"]), 1
    assert_select %(a[href="#{admin_tools_performance_path}"][data-turbo-frame="main"]), 1

    get :performance
    assert_response :success
    assert_template layout: 'v2/layouts/application'
    assert_select 'iframe#rails_performance_iframe[src=?]', rails_performance_path
  end
end
