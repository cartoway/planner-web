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

class AccountSummary
  # 3.1.0: capabilities.access is derived from Role.spaces['operations_mobile']
  # (space_usable?), not from a persisted operations_mobile.access field.
  CONTRACT_VERSION = '3.1.0'

  def self.for(user, account: nil)
    new(user, account || user.account).as_json
  end

  def initialize(user, account)
    @user = user
    @account = account
    @customer = user.customer
  end

  def as_json
    {
      contract_version: CONTRACT_VERSION,
      user_id: @user.id,
      account_uid: @account.uid,
      name: name,
      status: @user.status == 'suspended' ? 'suspended' : 'active',
      customer: {
        id: @customer.id,
        name: @customer.name.to_s,
        time_zone: @user.effective_time_zone
      },
      workspace: workspace,
      capabilities: capabilities,
      features: features,
      retention: retention,
      tracking_policy: tracking_policy
    }
  end

  private

  def name
    @account.name.presence || @account.email.to_s.split('@').first.presence || 'Driver'
  end

  def workspace
    role = @user.role
    body = {
      user_id: @user.id,
      customer: { id: @customer.id, name: @customer.name.to_s },
      role: {
        id: role&.id,
        name: role&.name.to_s,
        icon: role&.icon,
        color: role&.color.presence
      },
      status: @user.status == 'suspended' ? 'suspended' : 'active'
    }
    reseller = reseller_name
    body[:reseller_name] = reseller if reseller
    body
  end

  def reseller_name
    ids = @account.users.unscope(:order).filter_map { |user| user.customer&.reseller_id || user.reseller_id }
    return nil if ids.uniq.size < 2

    (@customer.reseller || @user.reseller)&.name
  end

  # Persistable JSON is capabilities-only; access mirrors the spaces gate for the app.
  def capabilities
    @user.mobile_capabilities.merge(
      'access' => @user.space_usable?('operations_mobile') ? 'usable' : 'none'
    )
  end

  def features
    devices = @customer.devices
    devices = devices.to_h if devices.respond_to?(:to_h)
    deliver = devices.is_a?(Hash) ? (devices['deliver'] || devices[:deliver] || {}) : {}
    {
      proofs: @customer.enable_proofs?,
      driver_move: ValueToBoolean.value_to_boolean(deliver['driver_move'] || deliver[:driver_move]),
      proof_geolocation: false
    }
  end

  def retention
    {
      position_retention_days: @customer.vehicle_position_retention_days,
      proof_retention_days: @customer.proof_retention_days,
      keep_trace: @customer.vehicle_position_keep_trace,
      visits_retention_months: 60,
      billing_archive_years: 5,
      after_expiry: 'anonymize'
    }
  end

  def tracking_policy
    {
      legal_basis: 'legitimate_interest',
      relationship: @user.relationship,
      notice_version: '1',
      notice_url: 'https://planner.cartoway.com/driver/notice',
      purposes: %w[eta_recipients dispatch_realtime],
      interrupted_after_s: 300
    }
  end
end
