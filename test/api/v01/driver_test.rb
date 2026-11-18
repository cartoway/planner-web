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

class V01::DriverTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear)
    @user = users(:user_one)
    @customer = @user.customer
    @customer.update!(operations_mobile: true, devices: { deliver: { enable: true } })
    @role = Role.create!(
      reseller: resellers(:reseller_one),
      name: "Driver #{SecureRandom.hex(4)}",
      spaces: Preferences::Catalog.normalize_spaces(
        'operations_mobile' => { 'visible' => true, 'usable' => true }
      ),
      operations_mobile: OperationsMobile.driver_default
    )
    @user.update!(role: @role)
    @installation = "inst-#{SecureRandom.hex(4)}"
    header 'X-Cartoway-App', 'android/1.0.0/3.0.0'
  end

  test 'session issues an account token that is stored only as a digest' do
    post '/api/0.1/driver/account/session', json(email: @user.email, password: '123456789', installation_id: @installation), 'CONTENT_TYPE' => 'application/json'
    assert_equal 201, last_response.status
    body = JSON.parse(last_response.body)
    token = body['account_token']
    assert token.start_with?('cda_')
    assert AccountSession.exists?(token_digest: DriverTokens.digest(token))
    refute AccountSession.pluck(:token_digest).include?(token)
    refute last_response.body.include?(DriverTokens.digest(token))
  end

  test 'workspace token reads me and an account token is rejected' do
    account_token = sign_in_account
    post "/api/0.1/driver/workspaces/#{@user.id}/token", {}.to_json, bearer(account_token)
    assert_equal 201, last_response.status
    workspace = JSON.parse(last_response.body)['workspace_token']
    assert workspace.start_with?('cdt_')

    get '/api/0.1/driver/me', {}, bearer(workspace)
    assert_equal 200, last_response.status
    me = JSON.parse(last_response.body)
    assert_equal '3.1.0', me['contract_version']
    assert_equal 'usable', me.dig('capabilities', 'access')
    assert_equal 'usable', me.dig('capabilities', 'capabilities', 'routes.read_assigned')
    assert_equal @user.id, me['user_id']
    assert_equal @user.account.name.presence || @user.email.to_s.split('@').first, me['name']
    assert_equal 'UTC', Time.zone.name

    get '/api/0.1/driver/me', {}, bearer(account_token)
    assert_equal 401, last_response.status
    assert_equal 'invalid_token', JSON.parse(last_response.body)['code']
  end

  test 'revoked device refuses the password and accepts it after reauthorization' do
    device = @user.account.account_devices.create!(installation_id: @installation, platform: 'android', revoked_at: Time.current)
    post '/api/0.1/driver/account/session', json(email: @user.email, password: '123456789', installation_id: @installation), 'CONTENT_TYPE' => 'application/json'
    assert_equal 403, last_response.status
    assert_equal 'device_revoked', JSON.parse(last_response.body)['code']
    assert_nil AccountSession.order(:id).last

    device.reauthorize!
    post '/api/0.1/driver/account/session', json(email: @user.email, password: '123456789', installation_id: @installation), 'CONTENT_TYPE' => 'application/json'
    assert_equal 201, last_response.status
    refute device.reload.revoked?
  end

  test 'a membership without a role is absent from workspaces and cannot take a token' do
    plain = users(:user_two)
    plain.update!(role_id: nil)
    plain.customer.update!(operations_mobile: true, devices: { deliver: { enable: true } })
    post '/api/0.1/driver/account/session', json(email: plain.email, password: '123456789', installation_id: @installation), 'CONTENT_TYPE' => 'application/json'
    assert_equal 201, last_response.status
    token = JSON.parse(last_response.body)['account_token']
    get '/api/0.1/driver/workspaces', {}, bearer(token)
    assert_equal 200, last_response.status
    ids = JSON.parse(last_response.body)['workspaces'].map { |row| row['user_id'] || row.dig('user', 'id') }
    refute_includes ids, plain.id
    post "/api/0.1/driver/workspaces/#{plain.id}/token", {}.to_json, bearer(token)
    assert_equal 403, last_response.status
    assert_equal 'capability_denied', JSON.parse(last_response.body)['code']
  end

  test 'two accounts keep a device with the same installation id' do
    other = users(:user_two)
    other.update!(role: @role)
    other.customer.update!(operations_mobile: true, devices: { deliver: { enable: true } })
    post '/api/0.1/driver/account/session', json(email: @user.email, password: '123456789', installation_id: @installation), 'CONTENT_TYPE' => 'application/json'
    assert_equal 201, last_response.status
    post '/api/0.1/driver/account/session', json(email: other.email, password: '123456789', installation_id: @installation), 'CONTENT_TYPE' => 'application/json'
    assert_equal 201, last_response.status
    assert_equal 2, AccountDevice.where(installation_id: @installation).count
  end

  test 'an account token is rejected on workspace routes and a workspace token on account routes' do
    account_token = sign_in_account
    post "/api/0.1/driver/workspaces/#{@user.id}/token", {}.to_json, bearer(account_token)
    workspace = JSON.parse(last_response.body)['workspace_token']
    [
      [:get, '/api/0.1/driver/me'],
      [:delete, '/api/0.1/driver/me']
    ].each do |verb, path|
      public_send(verb, path, {}, bearer(account_token))
      assert_equal 401, last_response.status, path
      assert_equal 'invalid_token', JSON.parse(last_response.body)['code'], path
    end
    [
      [:get, '/api/0.1/driver/workspaces'],
      [:delete, '/api/0.1/driver/account/session']
    ].each do |verb, path|
      public_send(verb, path, {}.to_json, bearer(workspace).merge('CONTENT_TYPE' => 'application/json'))
      assert_equal 401, last_response.status, path
      assert_equal 'invalid_token', JSON.parse(last_response.body)['code'], path
    end
  end

  test 'closed operations refuse a workspace token' do
    @customer.update!(operations_mobile: false)
    account_token = sign_in_account
    post "/api/0.1/driver/workspaces/#{@user.id}/token", {}.to_json, bearer(account_token)
    assert_equal 403, last_response.status
    assert_equal 'operations_disabled', JSON.parse(last_response.body)['code']
  end

  test 'a membership of another account is not found' do
    account_token = sign_in_account
    post "/api/0.1/driver/workspaces/#{users(:user_three).id}/token", {}.to_json, bearer(account_token)
    assert_equal 404, last_response.status
    assert_equal 'workspace_not_found', JSON.parse(last_response.body)['code']
    assert WorkspaceSwitchEvent.where(to_user_id: users(:user_three).id, result: 'refused').exists?
  end

  test 'api key together with a driver token is ambiguous' do
    account_token = sign_in_account
    get '/api/0.1/driver/workspaces', {}, bearer(account_token).merge('HTTP_API_KEY' => 'testkey1')
    assert_equal 401, last_response.status
    assert_equal 'ambiguous_auth', JSON.parse(last_response.body)['code']
  end

  test 'a mismatched workspace header does not rotate the token' do
    account_token = sign_in_account
    post "/api/0.1/driver/workspaces/#{@user.id}/token", {}.to_json, bearer(account_token)
    workspace = JSON.parse(last_response.body)['workspace_token']
    digest = DriverTokens.digest(workspace)
    get '/api/0.1/driver/me', {}, bearer(workspace).merge('HTTP_X_CARTOWAY_WORKSPACE' => users(:user_two).id.to_s)
    assert_equal 409, last_response.status
    assert_equal 'workspace_changed', JSON.parse(last_response.body)['code']
    assert_equal digest, UserSession.find_by(token_digest: digest).token_digest
    assert_nil UserSession.find_by(token_digest: digest).revoked_at
  end

  test 'deleting the account enqueues anonymization' do
    account_token = sign_in_account
    assert_difference 'Delayed::Job.count', 1 do
      delete '/api/0.1/driver/account', {}, bearer(account_token)
    end
    assert_equal 202, last_response.status
  end

  test 'too many session attempts are rate limited' do
    10.times do
      post '/api/0.1/driver/account/session', json(email: 'nobody-rate@example.com', password: 'wrong', installation_id: @installation), 'CONTENT_TYPE' => 'application/json'
    end
    post '/api/0.1/driver/account/session', json(email: 'nobody-rate@example.com', password: 'wrong', installation_id: @installation), 'CONTENT_TYPE' => 'application/json'
    assert_equal 429, last_response.status
    assert_equal 'rate_limited', JSON.parse(last_response.body)['code']
  end

  private

  def json(payload)
    payload.to_json
  end

  def bearer(token)
    { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => "Bearer #{token}" }
  end

  def sign_in_account
    post '/api/0.1/driver/account/session', json(email: @user.email, password: '123456789', installation_id: @installation), 'CONTENT_TYPE' => 'application/json'
    assert_equal 201, last_response.status
    JSON.parse(last_response.body)['account_token']
  end
end
