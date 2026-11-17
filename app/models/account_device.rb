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

class AccountDevice < ApplicationRecord
  belongs_to :account
  has_many :user_sessions, dependent: :delete_all
  has_many :account_sessions, dependent: :delete_all

  validates :installation_id, presence: true, uniqueness: { scope: :account_id }
  validates :platform, inclusion: { in: %w[ios android] }

  def revoked?
    revoked_at.present?
  end

  # A manager revokes every token of this device. Re-authorization clears the
  # flag and does not issue a token; the driver still has to sign in again.
  def revoke!
    transaction do
      update!(revoked_at: Time.current)
      user_sessions.where(revoked_at: nil).update_all(revoked_at: Time.current, revoked_reason: 'device_revoked')
      account_sessions.where(revoked_at: nil).update_all(revoked_at: Time.current)
    end
  end

  def reauthorize!
    update!(revoked_at: nil)
  end
end
