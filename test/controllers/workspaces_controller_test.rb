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

class WorkspacesControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @user = users(:user_one)
    @account = @user.account
    sign_in @user
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

  def begin_login_as(admin:, target:)
    sign_in admin
    session[WorkspaceSession::WORKSPACE_USER_SESSION] = target.id
  end

  def token_from_redirect
    uri = URI(response.redirect_url)
    Rack::Utils.parse_query(uri.fragment.to_s)['token'].presence ||
      Rack::Utils.parse_query(uri.query.to_s)['token']
  end

  test 'single web membership redirects choose to root' do
    get :choose
    assert_redirected_to root_path
  end

  test 'choose groups memberships by customer then user' do
    # Account has at most one user per customer; two customers → two groups.
    other = add_web_membership

    get :choose
    assert_response :success
    assert_select '.list-group-item.fw-semibold', text: @user.customer.name
    assert_select '.list-group-item.fw-semibold', text: other.customer.name
    assert_select '.list-group-item', text: /#{Regexp.escape(@user.email)}/
    assert_select '.list-group-item', text: /#{Regexp.escape(other.email)}/
    assert_select "form[action=?]", switch_workspace_path(user_id: other.id)
  end

  test 'switch membership changes last_user_id and clears current_driver_id' do
    other = add_web_membership
    session[:current_driver_id] = vehicles(:vehicle_one).id

    assert_difference 'WorkspaceSwitchEvent.count', 1 do
      post :switch, params: { user_id: other.id }
    end
    assert_redirected_to root_path
    assert_equal I18n.t('workspaces.switch.success', name: other.customer.name), flash[:notice]
    assert_nil session[:current_driver_id]
    assert_equal other.id, @account.reload.last_user_id
    assert_equal other.id, @controller.current_user.id
    assert_equal 'ok', WorkspaceSwitchEvent.order(:id).last.result
  end

  test 'switch with another account user_id is refused' do
    foreign = users(:user_three)
    assert_difference 'WorkspaceSwitchEvent.count', 1 do
      post :switch, params: { user_id: foreign.id }
    end
    assert_redirected_to root_path
    assert_equal I18n.t('workspaces.switch.failure'), flash[:alert]
    assert_equal 'refused', WorkspaceSwitchEvent.order(:id).last.result
  end

  test 'admin handoff login-as keeps warden admin and sets workspace user' do
    admin = users(:user_admin)
    sign_in admin
    target = users(:user_one)

    # Same-host connect-as claims inline (Turbo drops Location #token= fragments).
    post :handoff, params: { user_id: target.id }
    assert_redirected_to root_path
    assert_equal target.id, @controller.current_user.id
    assert_equal admin.id, @controller.true_user.id
    assert_equal target.id, session[:workspace_user_id]
    assert_nil session[:impersonator_user_id]
  end

  test 'claim prompt does not consume token' do
    admin = users(:user_admin)
    sign_in admin
    target = users(:user_one)
    token = Workspaces::HandoffToken.generate(user: target, impersonator: admin)

    # Functional tests call the action by name (routes map GET claim → claim_prompt).
    get :claim_prompt
    assert_response :success
    assert_select 'form#workspace-claim-form'
    assert_nil session[:workspace_user_id]

    post :claim, params: { token: token }
    assert_redirected_to root_path
    assert_equal target.id, @controller.current_user.id
  end

  test 'stop impersonating clears workspace user without switching warden' do
    admin = users(:user_admin)
    target = users(:user_one)
    begin_login_as(admin: admin, target: target)

    post :switch, params: { stop_impersonating: 1 }
    assert_redirected_to root_path
    assert_nil session[:workspace_user_id]
    assert_equal admin.id, @controller.true_user.id
    assert_equal admin.id, @controller.current_user.id
  end

  test 'planted workspace_user_id as non-admin is ignored' do
    sign_in @user
    session[:workspace_user_id] = users(:user_two).id

    get :choose
    assert_nil session[:workspace_user_id]
    assert_equal @user.id, @controller.current_user.id
    assert_equal @user.id, @controller.true_user.id
  end

  test 'mismatched workspace header on non-GET returns 409 with workspace-changed marker' do
    request.headers['X-Cartoway-Workspace'] = (@user.id + 999).to_s
    assert_no_difference 'WorkspaceSwitchEvent.count' do
      post :switch, params: { user_id: @user.id }
    end
    assert_response :conflict
    assert_equal '1', response.headers['X-Cartoway-Workspace-Changed']
  end

  test 'mismatched workspace header on GET is allowed' do
    add_web_membership
    request.headers['X-Cartoway-Workspace'] = (@user.id + 999).to_s
    get :choose
    assert_response :success
  end

  test 'handoff to foreign reseller user is refused' do
    sign_in users(:user_admin)
    foreign = users(:user_three)
    assert_not_equal users(:user_admin).reseller_id, foreign.customer.reseller_id

    assert_difference 'WorkspaceSwitchEvent.count', 1 do
      post :handoff, params: { user_id: foreign.id }
    end
    assert_redirected_to root_path
    assert_equal 'refused', WorkspaceSwitchEvent.order(:id).last.result
  end

  test 'invalid claim token on post redirects to sign in' do
    sign_out @user
    post :claim, params: { token: 'nope' }
    assert_redirected_to new_user_session_path
  end

  test 'handoff while login-as keeps warden admin and switches workspace user' do
    admin = users(:user_admin)
    first = users(:user_one)
    second = users(:user_two)
    assert_equal admin.reseller_id, second.customer.reseller_id

    begin_login_as(admin: admin, target: first)

    post :handoff, params: { user_id: second.id }
    assert_redirected_to root_path
    assert_equal second.id, @controller.current_user.id
    assert_equal admin.id, @controller.true_user.id
    assert_equal second.id, session[:workspace_user_id]
  end

  test 'handoff same-account while login-as keeps warden admin' do
    admin = users(:user_admin)
    first = users(:user_one)
    peer = add_web_membership
    assert_equal first.account_id, peer.account_id

    begin_login_as(admin: admin, target: first)

    post :handoff, params: { user_id: peer.id }
    assert_redirected_to root_path
    assert_equal peer.id, @controller.current_user.id
    assert_equal admin.id, @controller.true_user.id
    assert_equal peer.id, session[:workspace_user_id]
  end

  test 'switch membership while login-as is refused' do
    admin = users(:user_admin)
    first = users(:user_one)
    peer = add_web_membership
    begin_login_as(admin: admin, target: first)

    assert_difference 'WorkspaceSwitchEvent.count', 1 do
      post :switch, params: { user_id: peer.id }
    end
    assert_redirected_to root_path
    assert_equal I18n.t('workspaces.switch.failure'), flash[:alert]
    assert_equal 'refused', WorkspaceSwitchEvent.order(:id).last.result
    assert_equal first.id, @controller.current_user.id
    assert_equal admin.id, @controller.true_user.id
    assert_equal first.id, session[:workspace_user_id]
  end

  test 'claim refuses token whose impersonator is a foreign reseller admin' do
    local_admin = users(:user_admin)
    foreign_target = users(:user_three)
    assert_not_equal local_admin.reseller_id, foreign_target.customer.reseller_id

    foreign_account = Account.create!(
      uid: SecureRandom.uuid,
      email: "admin-r2-#{SecureRandom.hex(4)}@example.com",
      time_zone: 'Hawaii'
    )
    foreign_admin = User.create!(
      account: foreign_account,
      email: foreign_account.email,
      status: 'active',
      relationship: 'employee',
      reseller: resellers(:reseller_two),
      layer: layers(:layer_one),
      api_key: SecureRandom.hex(8),
      password: '123456789',
      confirmed_at: Time.current
    )

    token = Workspaces::HandoffToken.generate(user: foreign_target, impersonator: foreign_admin)
    sign_in local_admin
    before_id = local_admin.id

    post :claim, params: { token: token }
    assert_redirected_to root_path
    assert_equal I18n.t('workspaces.handoff.invalid'), flash[:alert]
    assert_equal before_id, @controller.true_user.id
    assert_nil session[:workspace_user_id]
  end

  test 'cold claim with impersonator token signs in target without login-as' do
    sign_out @user
    admin = users(:user_admin)
    target = users(:user_one)
    token = Workspaces::HandoffToken.generate(user: target, impersonator: admin)

    post :claim, params: { token: token }
    assert_redirected_to root_path
    assert_equal target.id, @controller.current_user.id
    assert_equal target.id, @controller.true_user.id
    assert_nil session[:workspace_user_id]
  end

  test 'signed-in non-admin cannot claim foreign login-as token' do
    admin = users(:user_admin)
    target = users(:user_two)
    token = Workspaces::HandoffToken.generate(user: target, impersonator: admin)
    sign_in @user

    assert_difference 'WorkspaceSwitchEvent.count', 1 do
      post :claim, params: { token: token }
    end
    assert_redirected_to root_path
    assert_equal I18n.t('workspaces.handoff.invalid'), flash[:alert]
    assert_equal 'refused', WorkspaceSwitchEvent.order(:id).last.result
    assert_equal @user.id, @controller.true_user.id
    assert_nil session[:workspace_user_id]
  end

  test 'claim refuses target whose reseller does not match request host' do
    sign_out @user
    foreign = users(:user_three)
    assert_not_equal @reseller.id, foreign.customer.reseller_id
    token = Workspaces::HandoffToken.generate(user: foreign)

    assert_difference 'WorkspaceSwitchEvent.count', 1 do
      post :claim, params: { token: token }
    end
    assert_redirected_to new_user_session_path
    assert_equal I18n.t('workspaces.handoff.invalid'), flash[:alert]
    assert_equal 'refused', WorkspaceSwitchEvent.order(:id).last.result
  end

  test 'claim token can only be consumed once' do
    admin = users(:user_admin)
    sign_in admin
    target = users(:user_one)
    token = Workspaces::HandoffToken.generate(user: target, impersonator: admin)

    post :claim, params: { token: token }
    assert_equal target.id, @controller.current_user.id
    assert_equal admin.id, @controller.true_user.id

    post :claim, params: { token: token }
    assert_redirected_to root_path
    assert_equal I18n.t('workspaces.handoff.invalid'), flash[:alert]
    assert_equal target.id, @controller.current_user.id
    assert_equal admin.id, @controller.true_user.id
  end
end
