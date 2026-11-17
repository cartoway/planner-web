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

class MembershipWithoutRoleControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @user = users(:user_one)
    @user.update!(role_id: nil)
  end

  test 'a planner url is refused like an unauthorized space' do
    @controller = DestinationsController.new
    sign_in @user
    get :index
    assert_redirected_to root_url
  end

  test 'the home menu hides planner spaces' do
    @controller = IndexController.new
    sign_in @user
    get :index
    assert_response :success
    assert_select %(a[href="#{plannings_path}"]), 0
    assert_select %(a[href="#{destinations_path}"]), 0
  end

  test 'the v2 menu uses the same space gate' do
    @controller = IndexController.new
    sign_in @user
    IndexController.stub_any_instance(:layout_by_resource, 'v2/layouts/application') do
      get :index
    end
    assert_response :success
    assert_select 'body.cartoway-v2', 1
    assert_select %(a[href="#{plannings_path}"]), 0
    assert_select %(a[href="#{destinations_path}"]), 0
  end

  test 'the reseller admin still opens accounts' do
    @controller = Admin::AccountsController.new
    sign_in users(:user_admin)
    get :index
    assert_response :success
  end
end
