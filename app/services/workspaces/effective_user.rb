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

# Resolve the effective User for a request: during admin login-as,
# session[:workspace_user_id] is the membership the app acts as.
module Workspaces
  class EffectiveUser
    def self.call(true_user, session)
      return true_user if true_user.nil? || !true_user.admin?

      wid = session && session[WorkspaceSession::WORKSPACE_USER_SESSION]
      return true_user if wid.blank?

      target = User.unscope(:order).find_by(id: wid)
      return true_user unless allowed?(true_user, target)

      target
    end

    def self.allowed?(admin, target)
      return false unless admin&.admin?
      return false unless target
      return false unless HandoffPolicy.target_eligible?(target)
      return false unless target.customer
      return false unless admin.reseller_id == target.customer.reseller_id

      true
    end
  end
end
