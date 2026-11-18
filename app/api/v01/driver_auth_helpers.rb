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
  module DriverAuthHelpers
    APP_HEADER = %r{\A(?:ios|android)/\d+\.\d+\.\d+/(\d+)\.\d+\.\d+\z}

    def bearer_token
      headers['Authorization'].to_s[/\ABearer\s+(\S+)\z/i, 1]
    end

    def driver_access?
      route_setting(:driver_access) == true
    end

    def account_access?
      route_setting(:account_access) == true
    end

    def current_workspace_user
      @current_workspace_user
    end

    def current_account
      @current_account
    end

    def require_capability!(key, level = :usable)
      caps = current_workspace_user&.mobile_capabilities || OperationsMobile.none
      actual = caps.dig('capabilities', key.to_s)
      actual = 'none' if actual.blank?
      rank = { 'none' => 0, 'visible' => 1, 'usable' => 2 }
      return if rank.fetch(actual, 0) >= rank.fetch(level.to_s, 2)

      driver_error!(403, 'capability_denied', 'Capability denied')
    end

    def require_app!
      match = headers['X-Cartoway-App'].to_s.match(APP_HEADER)
      driver_error!(422, 'validation_failed', 'Invalid X-Cartoway-App') unless match
      driver_error!(426, 'app_upgrade_required', 'App upgrade required') if match[1].to_i < 3
    end

    def driver_error!(status, code, message)
      error!({ message: message, status: status, code: code }, status)
    end

    def authenticate_driver!
      token = bearer_token
      driver_error!(401, 'invalid_token', 'Invalid token') if token.blank?

      result = Workspaces::Authenticate.call(
        token: token,
        header_user_id: headers['X-Cartoway-Workspace'],
        allow_workspace: driver_access?,
        allow_account: account_access?
      )
      driver_error!(result.status, result.code, result.message) unless result.ok

      @current_account = result.account
      @current_workspace_user = result.user
      @current_driver_device = result.device
      @driver_auth_kind = result.kind
    end

    def workspace_json(user)
      AccountSummary.for(user)[:workspace]
    end
  end
end
