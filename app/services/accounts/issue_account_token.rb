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

module Accounts
  class IssueAccountToken
    def self.call(account:, installation_id:, platform: nil)
      secret = nil
      Account.transaction do
        device = account.account_devices.find_or_initialize_by(installation_id: installation_id)
        device.platform = platform if platform.present? && device.platform.blank?
        device.platform ||= 'ios'
        device.last_seen_at = Time.current
        device.save!
        secret, digest = DriverTokens.generate(DriverTokens::PREFIX_ACCOUNT)
        session = account.account_sessions.create!(
          account_device: device,
          token_digest: digest,
          last_used_at: Time.current
        )
        account.account_sessions.where(account_device_id: device.id, revoked_at: nil)
               .where.not(id: session.id)
               .update_all(revoked_at: Time.current)
      end
      secret
    end
  end
end
