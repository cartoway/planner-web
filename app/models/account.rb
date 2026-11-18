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

class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :identities, dependent: :destroy
  has_many :account_devices, dependent: :destroy
  has_many :account_sessions, dependent: :delete_all
  has_many :workspace_switch_events, dependent: :delete_all
  belongs_to :last_user, class_name: 'User', optional: true

  before_validation :assign_uid, on: :create
  before_validation :nilify_email
  after_save :copy_email_to_open_memberships, if: :saved_change_to_email?

  validates :uid, presence: true, uniqueness: true
  validates :email, format: { with: Devise.email_regexp }, allow_blank: true
  validates :email, uniqueness: { case_sensitive: false, allow_nil: true }

  # Customer-side accounts for a reseller; excludes accounts that only have reseller-admin users.
  scope :for_reseller_customers, lambda { |reseller_id|
    admin_ids = User.unscope(:order).where(reseller_id: reseller_id, customer_id: nil).select(:account_id)
    joins(:users)
      .where(users: { customer_id: Customer.where(reseller_id: reseller_id).select(:id) })
      .where.not(accounts: { id: admin_ids })
      .distinct
  }

  def self.search(query)
    query = query.to_s.strip
    return all if query.blank?

    pattern = "%#{sanitize_sql_like(query)}%"
    where('accounts.email ILIKE :q OR COALESCE(accounts.name, \'\') ILIKE :q', q: pattern)
  end

  def self.lookup_email(email)
    cleaned = email.to_s.strip.downcase
    return nil if cleaned.blank?

    where('LOWER(email) = ?', cleaned).first
  end

  def anonymized?
    anonymized_at.present?
  end

  # Membership Devise should sign in. One membership changes nothing visible.
  # Several: last web membership that can still sign in, otherwise the first.
  def web_sign_in_user
    list = users.unscope(:order).order(:id).to_a
    return nil if list.empty?

    active = anonymized? ? [] : list.select { |user| user.status == 'active' }
    preferred = active.find { |user| user.id == last_user_id && user.web_channel_open? }
    preferred || active.find(&:web_channel_open?) || active.first || list.first
  end

  private

  def assign_uid
    self.uid ||= SecureRandom.uuid
  end

  def nilify_email
    self.email = email.to_s.strip.downcase.presence
  end

  def copy_email_to_open_memberships
    users.with_open_status.update_all(email: email.to_s)
  end
end
