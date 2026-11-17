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

class Admin::AccountsControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @account = accounts(:account_one)
    sign_in users(:user_admin)
  end

  test 'index is v2 and hides reseller admins' do
    enable_layout_v2!(users(:user_admin))
    get :index
    assert_response :success
    assert_select 'body.cartoway-v2', 1
    assert_select '#accounts-index-layout', 1
    assert_select '.destinations-sidebar-title-row h1', text: I18n.t('admin.accounts.index.title')
    assert_select '.destinations-sidebar-counts #count.data-info', 1
    assert_select '#accounts-search-form .destinations-search-icon.fa-magnifying-glass', 1
    assert_select '.destinations-list-toolbar .fa-check-square', 1
    assert_select 'turbo-frame#accounts_list', 1
    assert_select '#account_box.destinations-list-scroll', 1
    assert_select "#accounts-list .v2-index-card.destinations-index-card#account_#{@account.id}", 1
    assert_select %(a[href="#{new_admin_account_path}"][data-turbo-frame="form_sidebar"]), 1
    assert_select %(a[href="#{admin_accounts_path}"][data-turbo-frame="main"][data-turbo-action="advance"]), 1
    assert_select %(a[href="#{customers_path}"][data-turbo-frame="main"][data-turbo-action="advance"]), 1
    assert_select %(a[href="#{admin_users_path}"]), 0
    assert_select '[data-controller~="v2--index-selection"]', 1
    assert_select '#accounts-search-form[data-controller~="v2--list-filters"]', 1
    assert_select 'input#accounts-filter[name=q]', 1
    assert_select '[data-controller~="confirm-click"]', minimum: 1
    assert_select "#account_#{accounts(:account_admin).id}", 0
    assert_select 'table', 0
    assert_select '.panel', 0
    assert_select '.btn-default', 0
  end

  test 'index paginates accounts and keeps header count as total' do
    enable_layout_v2!(users(:user_admin))
    get :index, params: { per_page: 25, page: 1 }
    assert_response :success
    assert_select '#count', text: /\d+/
    assert_select '.destinations-list-toolbar-meta .dropdown-item', minimum: 3
    assert_select %(a[data-turbo-frame="accounts_list"][href*="per_page=50"]), minimum: 1
  end

  test 'index search filters accounts and updates total count' do
    enable_layout_v2!(users(:user_admin))
    @account.update!(name: 'UniqueFilterTokenXYZ')
    get :index, params: { q: 'UniqueFilterTokenXYZ' }
    assert_response :success
    assert_equal 1, assigns(:pagination)[:total]
    assert_select "#account_#{@account.id}", 1
    assert_select '#count', text: /1/
    assert_select 'input#accounts-filter[value=UniqueFilterTokenXYZ]', 1
  end

  test 'index dropdown lists memberships with connect-as links' do
    enable_layout_v2!(users(:user_admin))
    membership = users(:user_one)
    get :index
    assert_response :success
    assert_select "#accountMembershipsDropdown#{@account.id} .account-memberships-dropdown__row", count: 1
    assert_select "#accountMembershipsDropdown#{@account.id} .account-memberships-dropdown__customer", text: membership.customer.name
    assert_select "#accountMembershipsDropdown#{@account.id} .account-memberships-dropdown__role", 0
    assert_select "#accountMembershipsDropdown#{@account.id} a.account-memberships-dropdown__connect[href=?][data-turbo-method=?][data-turbo-frame=?]",
                  handoff_workspace_path(user_id: membership.id), 'post', '_top'
    # Must not nest a form inside accounts-destroy (would submit DELETE instead of handoff).
    assert_select "#accountMembershipsDropdown#{@account.id} form", 0
  end

  test 'index card prefers display name, is not a title link, and confirms email send' do
    enable_layout_v2!(users(:user_admin))
    @account.update!(name: 'Ada Lovelace')
    get :index
    assert_response :success
    card = "#account_#{@account.id}"
    assert_select "#{card} h2.v2-index-card-title", text: 'Ada Lovelace'
    assert_select "#{card} h2.v2-index-card-title a", 0
    assert_select "#{card} .destinations-card-address", text: /#{Regexp.escape(@account.email)}/
    assert_select "#{card} .destinations-card-address", text: /1\s+#{Regexp.escape(I18n.t('admin.accounts.index.spaces', count: 1))}/
    assert_select "#{card} .admin-user-role-icon", 0
    assert_select "#{card} a[href=?][data-turbo-method=?][data-turbo-confirm=?]",
                  send_email_admin_account_path(@account), 'post',
                  I18n.t('admin.accounts.form.send_email_confirm')
  end

  test 'admin index stays v2 when the layout preference is legacy' do
    enable_layout_legacy!(users(:user_admin))
    get :index
    assert_response :success
    assert_select 'body.cartoway-v2', 1
    assert_select '.v2-index-card.destinations-index-card', minimum: 1
  end

  test 'edit url renders the sidebar on the list' do
    get :edit, params: { id: @account }
    assert_response :success
    assert_select 'body.cartoway-v2', 1
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select '#account-form-sidebar', 1
  end

  test 'edit sidebar translates relationship options' do
    get :edit, params: { id: @account }
    assert_response :success
    membership = users(:user_one)
    select_id = "membership_relationship_#{membership.id}"
    assert_select "##{select_id} option[value=employee]", text: I18n.t('admin.accounts.relationships.employee')
    assert_select "##{select_id} option[value=independent]", text: I18n.t('admin.accounts.relationships.independent')
    assert_select "##{select_id} option[value=subcontractor_staff]", text: I18n.t('admin.accounts.relationships.subcontractor_staff')
  end

  test 'turbo frame edit returns only the sidebar' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @account }
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select 'body.cartoway-v2', 0
  end

  test 'turbo frame new returns the sidebar form with customer and role selects' do
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :new
    assert_response :success
    assert_select 'turbo-frame#form_sidebar', 1
    assert_select '#account-form-sidebar', 1
    assert_select 'label[for=account_name]', text: I18n.t('admin.accounts.form.name')
    assert_select 'input#account_name', 1
    assert_select 'input#account_phone', 1
    assert_select 'select#account_time_zone', 1
    assert_select 'select#customer_id option', minimum: 1
    assert_select 'select#role_id', 1
    assert_select 'body.cartoway-v2', 0
  end

  test 'turbo frame new locks customer when customer_id is provided' do
    customer = customers(:customer_one)
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :new, params: { customer_id: customer.id, return_to_customer_id: customer.id }
    assert_response :success
    assert_select 'input[type=hidden][name=customer_id][value=?]', customer.id.to_s
    assert_select 'input[type=hidden][name=return_to_customer_id][value=?]', customer.id.to_s
    assert_select 'select#customer_id', 0
    assert_select '.form-control-plaintext', text: customer.name
    assert_select 'a.btn-icon[data-turbo-frame=form_sidebar][href=?]',
                  edit_customer_path(customer, sidebar_tab: 'users')
    assert_select 'a.btn-icon .fa-chevron-left', 1
  end

  test 'turbo frame edit shows back to customer when return_to_customer_id is set' do
    customer = customers(:customer_one)
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :edit, params: { id: @account, return_to_customer_id: customer.id }
    assert_response :success
    assert_select 'a.btn-icon[data-turbo-frame=form_sidebar][href=?]',
                  edit_customer_path(customer, sidebar_tab: 'users')
    assert_select 'a.btn-icon .fa-chevron-left', 1
  end

  test 'create with return_to_customer_id redirects to customer users tab' do
    customer = customers(:customer_one)
    email = "from-customer-#{SecureRandom.hex(4)}@example.com"
    assert_difference 'Account.count', 1 do
      post :create, params: {
        customer_id: customer.id,
        return_to_customer_id: customer.id,
        account: { email: email, name: 'From Customer' }
      }
    end
    assert_redirected_to edit_customer_path(customer, sidebar_tab: 'users')
  end

  test 'create persists name phone and time zone on a new account' do
    email = "named-#{SecureRandom.hex(4)}@example.com"
    assert_difference 'Account.count', 1 do
      post :create, params: {
        customer_id: customers(:customer_one).id,
        account: {
          email: email,
          name: 'Ada Lovelace',
          phone: '+33123456789',
          time_zone: 'Paris'
        }
      }, format: :turbo_stream
    end
    assert_response :success
    account = Account.lookup_email(email)
    assert_equal 'Ada Lovelace', account.name
    assert_equal '+33123456789', account.phone
    assert_equal 'Paris', account.time_zone
  end

  test 'create new rejects an email that already exists' do
    assert_no_difference ['Account.count', 'User.count'] do
      post :create, params: {
        mode: 'new',
        customer_id: customers(:customer_one_other).id,
        account: { email: @account.email }
      }
    end
    assert_response :unprocessable_entity
    assert_select '.alert, .invalid-feedback, #error_explanation', minimum: 1
  end

  test 'create existing attaches a membership without creating an account' do
    digest = @account.encrypted_password
    customer = customers(:customer_one_other)
    assert_difference 'User.count', 1 do
      assert_no_difference 'Account.count' do
        post :create, params: {
          mode: 'existing',
          customer_id: customer.id,
          existing_account_id: @account.id
        }
      end
    end
    assert_response :redirect
    assert_equal digest, @account.reload.encrypted_password
    assert @account.users.exists?(customer_id: customer.id, status: 'active')
  end

  test 'turbo frame new existing mode lists attachable accounts' do
    customer = customers(:customer_one)
    @request.headers['Turbo-Frame'] = 'form_sidebar'
    get :new, params: { mode: 'existing', customer_id: customer.id, return_to_customer_id: customer.id }
    assert_response :success
    assert_select 'select#existing_account_id', 1
    assert_select 'input#account_email', 0
    assert_select 'input#account_name', 0
  end

  test 'destroy as turbo stream removes the card' do
    assert_difference 'Account.count', -1 do
      delete :destroy, params: { id: @account }, format: :turbo_stream
    end
    assert_response :success
    assert_match(/turbo-stream action="remove"/, response.body)
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_match(/id=['"]count['"]/, response.body)
  end

  test 'cannot destroy the signed-in admin account' do
    delete :destroy, params: { id: accounts(:account_admin) }
    assert_response :forbidden
  end

  test 'account_deletable? agrees for preloaded and unloaded accounts' do
    enable_layout_v2!(users(:user_admin))
    get :index
    loaded = assigns(:accounts).find { |account| account.id == @account.id }
    assert loaded
    assert loaded.association(:users).loaded?
    unloaded = Account.find(@account.id)
    assert_not unloaded.association(:users).loaded?
    assert @controller.account_deletable?(loaded)
    assert_equal @controller.account_deletable?(loaded), @controller.account_deletable?(unloaded)
    assert_select "#account_#{@account.id} input[name=?]:not([disabled])", "accounts[#{@account.id}]"
  end

  test 'account outside the reseller is not found' do
    get :edit, params: { id: accounts(:account_three) }
    assert_response :not_found
  end

  test 'create as turbo stream appends the card' do
    email = "member-#{SecureRandom.hex(4)}@example.com"
    assert_difference 'User.count', 1 do
      post :create, params: {
        customer_id: customers(:customer_one).id,
        account: { email: email }
      }, format: :turbo_stream
    end
    assert_response :success
    assert_match(/turbo-stream action="append"/, response.body)
    assert_match(/turbo-stream action="replace"/, response.body)
  end

  test 'create with a blank email is rejected' do
    assert_no_difference 'User.count' do
      post :create, params: {
        customer_id: customers(:customer_one).id,
        account: { email: '  ' }
      }
    end
    assert_response :unprocessable_entity
  end

  test 'update keeps membership role when role_id is foreign' do
    membership = users(:user_one)
    keep_role_id = membership.role_id
    foreign_role = roles(:role_catalog_two)
    assert_not_equal @reseller.id, foreign_role.reseller_id

    patch :update, params: {
      id: @account.id,
      account: { name: @account.name },
      memberships: {
        membership.id.to_s => {
          role_id: foreign_role.id,
          status: membership.status,
          relationship: membership.relationship,
          time_zone: membership.time_zone
        }
      }
    }, format: :turbo_stream

    assert_response :success
    assert_equal keep_role_id, membership.reload.role_id
  end

  test 'detach closes the membership from the sidebar' do
    membership = users(:user_one)
    patch :detach_membership, params: { id: membership.account_id, membership_id: membership.id }, format: :turbo_stream
    assert_response :success
    assert_equal 'detached', membership.reload.status
    assert_match(/form_sidebar/, response.body)
  end

  test 'old users index redirects to accounts' do
    @controller = Admin::UsersController.new
    get :index
    assert_redirected_to admin_accounts_path
  end
end
