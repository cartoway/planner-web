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
  # Shared by the app (channel mobile) and Planner web (channel web).
  class Activate
    Result = Struct.new(:status, :code, :message, :user, keyword_init: true)

    def self.call(account:, user_id:, channel:, from_user_id: nil)
      new(account, user_id, channel, from_user_id).call
    end

    def initialize(account, user_id, channel, from_user_id = nil)
      @account = account
      @user_id = user_id
      @channel = channel.to_s
      @from_user_id = from_user_id
    end

    def call
      user = @account.users.unscope(:order).find_by(id: @user_id)
      return refuse(user_id: @user_id, status: 404, code: 'workspace_not_found', message: 'Workspace not found') unless user
      return refuse(user: user, status: 403, code: 'workspace_not_active', message: 'Workspace is not active') unless user.status == 'active'
      return refuse(user: user, status: 404, code: 'workspace_not_found', message: 'Workspace not found') unless user.customer

      if @channel == 'mobile'
        return mobile_gates(user)
      elsif @channel == 'web'
        return web_gates(user)
      end

      refuse(user: user, status: 403, code: 'capability_denied', message: 'Capability denied')
    end

    private

    def mobile_gates(user)
      if user.customer.end_subscription && user.customer.end_subscription < Time.current
        return refuse(user: user, status: 402, code: 'subscription_expired', message: 'Subscription expired')
      end
      unless operations_open?(user)
        return refuse(user: user, status: 403, code: 'operations_disabled', message: 'Operations are disabled')
      end
      unless user.space_usable?('operations_mobile')
        return refuse(user: user, status: 403, code: 'capability_denied', message: 'Capability denied')
      end

      accept(user)
    end

    def web_gates(user)
      # Expired subscription: still allow web entry; ApplicationController shows @unsubscribed.
      unless user.web_channel_open?
        return refuse(user: user, status: 403, code: 'capability_denied', message: 'Capability denied')
      end

      accept(user)
    end

    def operations_open?(user)
      customer = user.customer
      customer.operations_mobile? && customer.device.operations_enabled?
    end

    def accept(user)
      record('ok', user)
      Result.new(status: 200, code: nil, message: nil, user: user)
    end

    def refuse(status:, code:, message:, user: nil, user_id: nil)
      record('refused', user, user_id: user_id || user&.id)
      Result.new(status: status, code: code, message: message, user: user)
    end

    def record(result, user, user_id: nil)
      WorkspaceSwitchEvent.create!(
        account: @account,
        from_user_id: @from_user_id,
        to_user_id: user&.id || user_id,
        channel: @channel,
        result: result,
        created_at: Time.current
      )
    end
  end
end
