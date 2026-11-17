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

module V01
  class DriverTimeZone
    def initialize(app)
      @app = app
    end

    def call(env)
      previous = Time.zone
      @app.call(env)
    ensure
      Time.zone = previous
    end
  end

  class Driver < Grape::API
    use DriverTimeZone
    helpers V01::DriverAuthHelpers

    before do
      token = bearer_token
      api_key = headers['Api-Key'].presence || params[:api_key].presence
      if api_key.present? && token.present? && (DriverTokens.workspace?(token) || DriverTokens.account?(token))
        driver_error!(401, 'ambiguous_auth', 'Ambiguous authentication')
      end

      if driver_access? || account_access?
        authenticate_driver!
        Time.zone = current_workspace_user.effective_time_zone if current_workspace_user
      elsif token.present? && (DriverTokens.workspace?(token) || DriverTokens.account?(token))
        driver_error!(401, 'invalid_token', 'Invalid token')
      end
    end

    rescue_from Grape::Exceptions::ValidationErrors do |error|
      error!({ message: error.message, status: 422, code: 'validation_failed' }, 422)
    end

    resource :driver do
      route_setting :driver_access, true
      desc 'Current workspace' do
        tags ['identite']
      end
      get :me do
        require_app!
        AccountSummary.for(current_workspace_user)
      end
      unset_route_setting :driver_access

      route_setting :driver_access, true
      desc 'Leave the workspace' do
        tags ['identite']
      end
      delete :me do
        user = current_workspace_user
        if user.customer && user.customer.users.unscope(:order).where(status: 'active').where.not(id: user.id).none?
          driver_error!(403, 'capability_denied', 'Capability denied')
        end
        user.update!(status: 'detached')
        status 204
        body false
      end
      unset_route_setting :driver_access

      route_setting :driver_access, true
      route_setting :account_access, true
      desc 'Delete the account' do
        tags ['identite']
      end
      delete :account do
        Accounts::AnonymizeJob.perform_later(current_account.id)
        status 202
        { message: 'Accepted', status: 202 }
      end
      unset_route_setting :driver_access
      unset_route_setting :account_access

      route_setting :driver_access, true
      route_setting :account_access, true
      desc 'Register the current device' do
        tags ['identite']
      end
      params do
        requires :installation_id, type: String
        requires :platform, type: String, values: %w[ios android]
        requires :app_version, type: String
        requires :locale, type: String
        optional :os_version, type: String
        optional :push_provider, type: String, values: %w[fcm apns expo]
        optional :push_token, type: String
        optional :notifications_permission, type: String, values: %w[granted denied provisional undetermined]
      end
      put 'devices/current' do
        device = current_account.account_devices.find_or_initialize_by(installation_id: params[:installation_id])
        driver_error!(403, 'device_revoked', 'This device must be authorized again by a manager') if device.revoked?

        device.assign_attributes(
          platform: params[:platform],
          app_version: params[:app_version],
          locale: params[:locale],
          os_version: params[:os_version],
          push_provider: params[:push_provider],
          push_token: params[:push_token],
          notifications_permission: params[:notifications_permission],
          last_seen_at: Time.current
        )
        device.save!
        {
          installation_id: device.installation_id,
          platform: device.platform,
          app_version: device.app_version,
          os_version: device.os_version,
          locale: device.locale,
          push_provider: device.push_provider,
          push_token: device.push_token,
          notifications_permission: device.notifications_permission
        }.compact
      end
      unset_route_setting :driver_access
      unset_route_setting :account_access

      desc 'Sign in' do
        tags ['espaces']
      end
      params do
        requires :email, type: String
        requires :password, type: String
        requires :installation_id, type: String
      end
      post 'account/session' do
        require_app!
        account = Account.lookup_email(params[:email])
        password_ok = account && !account.anonymized? && account.encrypted_password.present? &&
                      Devise::Encryptor.compare(User, account.encrypted_password, params[:password])
        driver_error!(401, 'invalid_credentials', 'Invalid credentials') unless password_ok

        device = account.account_devices.find_by(installation_id: params[:installation_id])
        if device&.revoked?
          driver_error!(403, 'device_revoked', 'This device must be authorized again by a manager')
        end

        token = Accounts::IssueAccountToken.call(
          account: account,
          installation_id: params[:installation_id],
          platform: headers['X-Cartoway-App'].to_s.split('/').first
        )
        {
          account_token: token,
          account_uid: account.uid,
          workspaces: Workspaces::ListFor.call(account, channel: :mobile).map { |user| workspace_json(user) }
        }
      end

      route_setting :account_access, true
      desc 'Revoke the account token' do
        tags ['espaces']
      end
      delete 'account/session' do
        session = AccountSession.find_by(token_digest: DriverTokens.digest(bearer_token))
        session&.update!(revoked_at: Time.current)
        status 204
        body false
      end
      unset_route_setting :account_access

      route_setting :account_access, true
      desc 'List workspaces' do
        tags ['espaces']
      end
      get :workspaces do
        require_app!
        { workspaces: Workspaces::ListFor.call(current_account, channel: :mobile).map { |user| workspace_json(user) } }
      end
      unset_route_setting :account_access

      route_setting :account_access, true
      desc 'Issue a workspace token' do
        tags ['espaces']
      end
      params do
        requires :user_id, type: Integer
      end
      post 'workspaces/:user_id/token' do
        require_app!
        result = Workspaces::Activate.call(account: current_account, user_id: params[:user_id], channel: :mobile)
        driver_error!(result.status, result.code, result.message) unless result.status == 200

        device = @current_driver_device
        device ||= current_account.account_devices.order(:id).last
        driver_error!(422, 'validation_failed', 'Device required') unless device

        token = Workspaces::IssueToken.call(user: result.user, device: device)
        { workspace_token: token, account: AccountSummary.for(result.user) }
      end
      unset_route_setting :account_access
    end
  end
end
