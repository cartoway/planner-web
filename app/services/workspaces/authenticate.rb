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

module Workspaces
  # Resolves a bearer token. A mismatching X-Cartoway-Workspace returns 409
  # and does not write. An expired or revoked token is 401 whatever the header.
  class Authenticate
    Result = Struct.new(:ok, :status, :code, :message, :user, :account, :session, :device, :kind, keyword_init: true)

    def self.call(token:, header_user_id: nil, allow_workspace: false, allow_account: false)
      new(token, header_user_id, allow_workspace, allow_account).call
    end

    def initialize(token, header_user_id, allow_workspace, allow_account)
      @token = token.to_s
      @header_user_id = header_user_id
      @allow_workspace = allow_workspace
      @allow_account = allow_account
    end

    def call
      if DriverTokens.account?(@token)
        return failure(401, 'invalid_token', 'Invalid token') unless @allow_account

        return authenticate_account
      end
      if DriverTokens.workspace?(@token)
        return failure(401, 'invalid_token', 'Invalid token') unless @allow_workspace

        return authenticate_workspace
      end

      failure(401, 'invalid_token', 'Invalid token')
    end

    private

    def authenticate_workspace
      session = UserSession.find_by(token_digest: DriverTokens.digest(@token))
      return failure(401, 'invalid_token', 'Invalid token') unless session
      return failure(401, 'invalid_token', 'Invalid token') if session.revoked? || session.account_device&.revoked?

      if idle?(session.last_used_at)
        session.update_columns(revoked_at: Time.current, revoked_reason: 'inactive')
        return failure(401, 'invalid_token', 'Invalid token')
      end

      user = session.user
      if @header_user_id.present? && @header_user_id.to_i != user.id
        return failure(409, 'workspace_changed', 'Workspace changed')
      end

      denied = gate(user)
      return denied if denied

      touch(session)
      Result.new(ok: true, user: user, account: user.account, session: session, device: session.account_device, kind: :workspace)
    end

    def authenticate_account
      session = AccountSession.find_by(token_digest: DriverTokens.digest(@token))
      return failure(401, 'invalid_token', 'Invalid token') unless session
      return failure(401, 'invalid_token', 'Invalid token') if session.revoked_at.present? || session.account_device&.revoked?
      return failure(401, 'invalid_token', 'Invalid token') if session.account&.anonymized?

      if idle?(session.last_used_at)
        session.update_columns(revoked_at: Time.current)
        return failure(401, 'invalid_token', 'Invalid token')
      end

      touch(session)
      Result.new(ok: true, account: session.account, session: session, device: session.account_device, kind: :account)
    end

    def gate(user)
      return failure(403, 'workspace_not_active', 'Workspace is not active') unless user.status == 'active'
      return failure(401, 'invalid_token', 'Invalid token') if user.account&.anonymized?
      return failure(404, 'workspace_not_found', 'Workspace not found') unless user.customer

      if user.customer.end_subscription && user.customer.end_subscription < Time.current
        return failure(402, 'subscription_expired', 'Subscription expired')
      end
      unless user.customer.operations_mobile? && user.customer.device.operations_enabled?
        return failure(403, 'operations_disabled', 'Operations are disabled')
      end
      return failure(403, 'capability_denied', 'Capability denied') unless user.space_usable?('operations_mobile')

      nil
    end

    def idle?(last_used_at)
      last_used_at.present? && last_used_at < DriverTokens::IDLE_LIMIT.ago
    end

    def touch(session)
      return if session.last_used_at && session.last_used_at > DriverTokens::TOUCH_EVERY.ago

      session.update_columns(last_used_at: Time.current)
    end

    def failure(status, code, message)
      Result.new(ok: false, status: status, code: code, message: message)
    end
  end
end
