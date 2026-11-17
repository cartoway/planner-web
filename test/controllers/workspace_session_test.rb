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

class WorkspaceSessionTest < ActionController::TestCase
  tests WorkspacesController

  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @user = users(:user_one)
    @account = @user.account
  end

  def add_web_membership(customer: customers(:customer_one_other))
    role = customer.reseller_id == resellers(:reseller_two).id ? roles(:role_catalog_two) : roles(:role_catalog)
    @account.users.create!(
      customer: customer,
      email: @account.email,
      status: 'active',
      relationship: 'employee',
      role: role,
      layer: layers(:layer_one),
      api_key: SecureRandom.hex(8)
    )
  end

  test 'after_sign_in goes home for a single web membership' do
    sign_in @user
    assert_equal 1, Workspaces::ListFor.call(@account, channel: :web).size
    assert_equal root_path, @controller.after_sign_in_path_for(@user)
  end

  test 'after_sign_in uses last_user_id when still web-open' do
    other = add_web_membership
    @account.update_columns(last_user_id: other.id)
    sign_in @user
    assert_equal root_path, @controller.after_sign_in_path_for(@user)
    assert_equal other.id, @controller.current_user.id
  end

  test 'after_sign_in shows choose when preferred membership activate fails' do
    other = add_web_membership
    @account.update_columns(last_user_id: other.id)
    before_last = @account.last_user_id
    sign_in @user
    Workspaces::Activate.stubs(:call).returns(
      Workspaces::Activate::Result.new(status: 403, code: 'capability_denied', message: 'nope', user: other)
    )
    assert_equal choose_workspace_path, @controller.after_sign_in_path_for(@user)
    assert_equal @user.id, @controller.current_user.id
    assert_equal before_last, @account.reload.last_user_id
  end

  test 'after_sign_in shows choose when current preferred lost web workspace' do
    other = add_web_membership
    @account.update_columns(last_user_id: @user.id)
    sign_in @user
    Workspaces::ListFor.stubs(:call).returns([@user, other])
    Workspaces::ListFor.stubs(:web_workspace?).with(@user).returns(false)
    Workspaces::ListFor.stubs(:web_workspace?).with(other).returns(true)
    assert_equal choose_workspace_path, @controller.after_sign_in_path_for(@user)
    assert_equal @user.id, @account.reload.last_user_id
  end

  test 'after_sign_in shows choose when last_user_id is suspended' do
    suspended = add_web_membership
    add_web_membership(customer: customers(:customer_two))
    @account.update_columns(last_user_id: suspended.id)
    suspended.update_columns(status: 'suspended')
    sign_in @user
    assert_equal choose_workspace_path, @controller.after_sign_in_path_for(@user)
  end

  test 'chip helpers respect menu and filter thresholds' do
    sign_in @user
    assert_not @controller.workspace_show_menu?
    assert_not @controller.workspace_show_filter?

    @controller.stubs(:workspace_web_list).returns(Array.new(2) { @user })
    assert @controller.workspace_show_menu?
    assert_not @controller.workspace_show_filter?

    @controller.stubs(:workspace_web_list).returns(Array.new(5) { @user })
    assert @controller.workspace_show_menu?
    assert @controller.workspace_show_filter?
  end

  test 'workspace_web_list is memoized per request' do
    sign_in @user
    Workspaces::ListFor.expects(:call).once.returns([@user])
    2.times { @controller.workspace_web_list }
  end

  test 'admin reseller scope lists all reseller web users' do
    admin = users(:user_admin)
    sign_in admin
    assert @controller.workspace_reseller_scope?
    list = @controller.workspace_reseller_web_list
    assert_includes list.map(&:id), users(:user_one).id
    assert_includes list.map(&:id), users(:user_two).id
    assert_not_includes list.map(&:id), users(:user_three).id
    assert @controller.workspace_show_menu?
  end

  test 'login-as keeps reseller scope with true_user admin' do
    admin = users(:user_admin)
    sign_in admin
    session[WorkspaceSession::WORKSPACE_USER_SESSION] = @user.id
    assert @controller.workspace_impersonating?
    assert_equal @user, @controller.current_user
    assert_equal admin, @controller.true_user
    assert @controller.workspace_reseller_scope?
    assert_equal admin, @controller.workspace_reseller_admin
    assert @controller.workspace_show_menu?
    assert_includes @controller.workspace_reseller_web_list.map(&:id), @user.id
  end

  test 'planted workspace_user_id without admin true_user is cleared' do
    sign_in @user
    session[WorkspaceSession::WORKSPACE_USER_SESSION] = users(:user_two).id
    assert_not @controller.workspace_impersonating?
    assert_nil session[WorkspaceSession::WORKSPACE_USER_SESSION]
    assert_equal @user, @controller.current_user
  end
end
