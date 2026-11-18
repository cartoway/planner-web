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
  class ListFor
    def self.call(account, channel:)
      channel = channel.to_s
      return [] if account.nil? || account.anonymized?
      return [] unless %w[mobile web].include?(channel)

      account.users.unscope(:order).where(status: 'active').includes(:customer, :role, customer: :reseller).select do |user|
        channel == 'mobile' ? mobile_workspace?(user) : web_workspace?(user)
      end
    end

    # Active memberships with mobile access but no web Planner access (note under the menu).
    def self.mobile_only(account)
      return [] if account.nil? || account.anonymized?

      account.users.unscope(:order).where(status: 'active').includes(:customer, :role).select do |user|
        mobile_workspace?(user) && !web_workspace?(user)
      end
    end

    def self.mobile_workspace?(user)
      customer = user.customer
      return false unless customer
      return false unless customer.operations_mobile?
      return false unless customer.device.operations_enabled?
      return false if customer.end_subscription && customer.end_subscription < Time.current

      user.space_usable?('operations_mobile')
    end

    def self.web_workspace?(user)
      return false unless user.customer
      return false unless user.web_channel_open?
      # Blank role may still sign in, but is not a switchable Planner workspace.
      return false if user.role_id.blank?

      true
    end

    # Active web memberships for every customer of +admin+'s reseller (admin chip list).
    def self.reseller_web(admin)
      return [] unless admin&.admin? && admin.reseller_id

      User.unscope(:order)
          .joins(:customer)
          .where(status: 'active', customers: { reseller_id: admin.reseller_id })
          .includes(:account, :customer, :role, customer: :reseller)
          .select { |user| web_workspace?(user) }
          .sort_by { |user| [user.customer.name.to_s.downcase, user.email.to_s.downcase] }
    end
  end
end
