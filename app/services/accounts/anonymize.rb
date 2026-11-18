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
  class Anonymize
    def self.call(account)
      return if account.nil? || account.anonymized?

      Account.transaction do
        account.users.unscope(:order).find_each do |user|
          user.update!(status: 'detached') unless user.status == 'detached'
          user.revoke_web_credentials!
        end
        user_ids = account.users.unscope(:order).select(:id)
        UserSession.where(user_id: user_ids, revoked_at: nil).update_all(revoked_at: Time.current, revoked_reason: 'account_deleted')
        account.account_sessions.where(revoked_at: nil).update_all(revoked_at: Time.current)
        account.account_devices.where(revoked_at: nil).update_all(revoked_at: Time.current)
        account.users.unscope(:order).update_all(email: '')
        account.update!(
          name: 'Anonymized',
          email: nil,
          phone: nil,
          encrypted_password: Devise::Encryptor.digest(User, SecureRandom.hex(32)),
          anonymized_at: Time.current,
          reset_password_token: nil,
          reset_password_sent_at: nil,
          confirmation_token: nil,
          unconfirmed_email: nil
        )
      end
    end
  end
end
