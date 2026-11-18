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
  # Short-lived one-shot signed token for cross-host open and admin login-as.
  # impersonator_id marks login-as (Warden stays admin; workspace user in session).
  # Parse verifies the signature; consume! burns the JTI after policy allows.
  class HandoffToken
    PURPOSE = 'workspace_handoff'
    TTL = 60.seconds

    Result = Struct.new(:user, :impersonator, :jti, keyword_init: true)

    def self.generate(user:, impersonator: nil)
      jti = SecureRandom.uuid
      payload = {
        'user_id' => user.id,
        'impersonator_id' => impersonator&.id,
        'jti' => jti
      }
      token = verifier.generate(payload, purpose: PURPOSE, expires_in: TTL)
      jti_store.write(cache_key(jti), true, expires_in: TTL)
      token
    end

    # Verify signature and load users without consuming the one-shot JTI.
    def self.parse(token)
      return nil if token.blank?

      payload = verifier.verified(token, purpose: PURPOSE)
      return nil unless payload.is_a?(Hash)

      jti = payload['jti'].to_s
      return nil if jti.blank?

      user = User.find_by(id: payload['user_id'])
      return nil unless user

      impersonator = payload['impersonator_id'].present? ? User.find_by(id: payload['impersonator_id']) : nil
      Result.new(user: user, impersonator: impersonator, jti: jti)
    end

    # Atomically burn JTI. Returns false if already consumed or never issued.
    def self.consume!(jti)
      return false if jti.blank?

      jti_store.delete(cache_key(jti))
    end

    def self.verifier
      Rails.application.message_verifier('workspace_handoff_v1')
    end

    # Shared store: planner_cache (Redis in prod, FileStore in dev). NullStore (tests)
    # never retains keys — use a process MemoryStore so one-shot still works in CI.
    def self.jti_store
      store = Rails.application.config.planner_cache
      return store unless store.is_a?(ActiveSupport::Cache::NullStore)

      @jti_store ||= ActiveSupport::Cache::MemoryStore.new
    end
    private_class_method :jti_store

    def self.cache_key(jti)
      "workspace_handoff:jti:#{jti}"
    end
    private_class_method :cache_key
  end
end
