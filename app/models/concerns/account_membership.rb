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

# Membership credentials delegate to Account. The Devise session stays on User.
module AccountMembership # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  STATUSES = %w[pending active suspended detached rejected].freeze
  OPEN_STATUSES = %w[pending active suspended].freeze
  RELATIONSHIPS = %w[employee independent subcontractor_staff].freeze

  included do
    belongs_to :account, autosave: true
    has_many :user_sessions, dependent: :delete_all

    before_validation :ensure_account, on: :create
    # before_validation (not before_save): belongs_to autosave runs in before_save and
    # would otherwise miss account.email/password changes assigned too late.
    before_validation :assign_account_credentials
    after_save :cut_access_when_closed
    after_save :mirror_sign_in_trace, if: :saved_change_to_sign_in_count?

    validates :status, inclusion: { in: STATUSES }
    validates :relationship, inclusion: { in: RELATIONSHIPS }
    validates :email, format: { with: Devise.email_regexp }, allow_blank: true

    scope :active, -> { where(status: 'active') }
    scope :with_open_status, -> { where(status: OPEN_STATUSES) }
    scope :for_customer_ids, ->(customer_ids) { where(customer_id: customer_ids) }
  end

  class_methods do
    def find_for_database_authentication(warden_conditions)
      email = warden_conditions.to_h.with_indifferent_access[:email]
      if email.present?
        account = Account.lookup_email(email)
        return nil unless account

        return account.web_sign_in_user
      end

      super
    end
  end

  def password=(new_password)
    @password_assigned = true
    super
  end

  def valid_password?(password)
    digest = account&.encrypted_password.presence || encrypted_password
    return false if digest.blank?

    Devise::Encryptor.compare(self.class, digest, password)
  end

  # No role still signs in, but no Planner space is visible (see read_spaces_hash).
  # A role with no visible space cannot sign in. Reseller admins always can.
  def web_channel_open?
    return false unless status == 'active'
    return false if account&.anonymized?
    return true if admin?
    return true if role_id.blank?

    ::Preferences::Catalog::WEB_SPACE_KEYS.any? { |key| space_visible?(key) }
  end

  def active_for_authentication?
    super && web_channel_open?
  end

  def inactive_message
    return :anonymized if account&.anonymized?
    return :suspended unless status == 'active'

    :no_web_access
  end

  def effective_time_zone
    self[:time_zone].presence || account&.time_zone.presence || 'UTC'
  end

  def mobile_capabilities
    return OperationsMobile.none if role_id.blank?

    OperationsMobile.read(role&.operations_mobile)
  end

  def revoke_web_credentials!
    updates = {
      remember_created_at: nil,
      reset_password_token: nil,
      reset_password_sent_at: nil
    }
    updates[:session_token] = SecureRandom.hex(16) if has_attribute?(:session_token)
    update_columns(updates)
    account&.update_columns(
      remember_created_at: nil,
      reset_password_token: nil,
      reset_password_sent_at: nil
    )
  end

  # Skip Devise's email uniqueness: the unique key is accounts.email.
  def devise_will_save_change_to_email?
    false
  end

  def password_required?
    return false if account&.persisted? && account.encrypted_password.present? && !@password_assigned

    super
  end

  def email_required?
    false
  end

  def authenticatable_salt
    salt = super
    token = has_attribute?(:session_token) ? self[:session_token] : nil
    token.present? ? "#{salt}#{token}" : salt
  end

  private

  def ensure_account
    return if account

    found = Account.lookup_email(self[:email]) if self[:email].present?
    if found
      self.account = found
      self.email = found.email if found.email.present?
      self.encrypted_password = found.encrypted_password if found.encrypted_password.present?
      @password_assigned = false
    else
      build_account(
        email: self[:email].presence,
        encrypted_password: encrypted_password.to_s,
        time_zone: time_zone,
        locale: locale,
        confirmed_at: confirmed_at,
        confirmation_token: confirmation_token
      )
    end
  end

  def assign_account_credentials
    ensure_account unless account
    return unless account

    if account.new_record?
      account.email = self[:email].presence
      account.encrypted_password = encrypted_password if encrypted_password.present?
      account.time_zone ||= time_zone
      account.locale ||= locale
      account.confirmed_at ||= confirmed_at
      account.confirmation_token ||= confirmation_token
    elsif @password_assigned && encrypted_password.present?
      account.encrypted_password = encrypted_password
    end

    return unless will_save_change_to_email? && self[:email].present? && account.persisted?

    account.email = self[:email].presence
  end

  def cut_access_when_closed
    return unless saved_change_to_status?
    return if status == 'active' || status_before_last_save.nil?

    revoke_web_credentials!
    user_sessions.where(revoked_at: nil).update_all(revoked_at: Time.current, revoked_reason: status)
  end

  def mirror_sign_in_trace
    account&.update_columns(
      sign_in_count: sign_in_count.to_i,
      current_sign_in_at: current_sign_in_at,
      last_sign_in_at: last_sign_in_at,
      current_sign_in_ip: current_sign_in_ip,
      last_sign_in_ip: last_sign_in_ip
    )
  end
end
