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
  # Who may hand off into a target membership, and whether claim is login-as
  # (Decision#impersonator = real admin that stays on Warden; workspace user in session).
  class HandoffPolicy
    Decision = Struct.new(:allowed, :impersonator, keyword_init: true)

    # +actor+ is the real signed-in user (true_user); +reseller_admin+ is that admin
    # when login-as / reseller scope is active.
    def self.authorize(actor:, target:, reseller_admin: nil)
      return Decision.new(allowed: false, impersonator: nil) unless actor && target
      return Decision.new(allowed: false, impersonator: nil) unless target_eligible?(target)

      # Same-account membership handoff: keep login-as admin when already in login-as.
      if actor.account_id == target.account_id
        return Decision.new(allowed: true, impersonator: impersonator_for(reseller_admin, target))
      end

      admin = reseller_admin
      return Decision.new(allowed: false, impersonator: nil) unless admin&.admin?
      return Decision.new(allowed: false, impersonator: nil) unless target.customer
      return Decision.new(allowed: false, impersonator: nil) unless target.customer.reseller_id == admin.reseller_id

      Decision.new(allowed: true, impersonator: impersonator_for(admin, target))
    end

    # Resolve claim: cold (no actor) may open target without login-as; signed-in non-admin
    # only same-account (cross-host); login-as only for matching admin. Never let a
    # non-admin adopt a foreign membership via a stolen token.
    def self.claim(actor:, target:, token_impersonator:, current_impersonator: nil)
      return Decision.new(allowed: false, impersonator: nil) unless target
      return Decision.new(allowed: false, impersonator: nil) unless target_eligible?(target)

      if actor && !actor.admin?
        return Decision.new(allowed: false, impersonator: nil) if token_impersonator
        return Decision.new(allowed: false, impersonator: nil) unless actor.account_id == target.account_id
      end

      if actor&.admin? &&
         !(target.customer && actor.reseller_id == target.customer.reseller_id)
        return Decision.new(allowed: false, impersonator: nil)
      end

      if actor&.admin? && token_impersonator &&
         token_impersonator.reseller_id != actor.reseller_id
        return Decision.new(allowed: false, impersonator: nil)
      end

      Decision.new(
        allowed: true,
        impersonator: resolve_impersonator(actor, target, token_impersonator, current_impersonator)
      )
    end

    # Same gates as Workspaces::Activate web channel (status + web spaces open).
    def self.target_eligible?(target)
      target.status == 'active' && Workspaces::ListFor.web_workspace?(target)
    end

    def self.impersonator_for(admin, target)
      return nil unless admin&.admin?
      return nil unless target&.customer
      return nil if target.id == admin.id
      return nil if admin.account_id == target.account_id
      return nil unless admin.reseller_id == target.customer.reseller_id

      admin
    end
    private_class_method :impersonator_for

    def self.resolve_impersonator(actor, target, token_impersonator, current_impersonator)
      return nil unless target&.customer

      if actor&.admin? &&
         actor.reseller_id == target.customer.reseller_id &&
         actor.id != target.id &&
         actor.account_id != target.account_id
        return actor
      end

      # Continue login-as: real admin already on Warden + matching token.
      if current_impersonator&.admin? &&
         token_impersonator&.id == current_impersonator.id &&
         current_impersonator.reseller_id == target.customer.reseller_id
        return current_impersonator
      end

      nil
    end
    private_class_method :resolve_impersonator
  end
end
