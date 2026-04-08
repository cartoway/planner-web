# Copyright © Mapotempo, 2013-2016
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable,
         :validatable, :omniauthable, omniauth_providers: [:entra_id]

  default_scope { order(Arel.sql('LOWER(email)')) }

  nilify_blanks
  auto_strip_attributes :url_click2call

  belongs_to :reseller, optional: true
  belongs_to :customer, optional: true # Admin has no customer
  belongs_to :role, optional: true
  belongs_to :layer
  has_many :identities, dependent: :destroy

  after_initialize :assign_defaults, if: -> { new_record? }
  before_validation :assign_defaults_layer, if: -> { new_record? }
  before_save :set_time_zone

  validates :customer, presence: true, unless: :admin?
  validates :layer, presence: true
  validate :role_matches_customer_reseller, unless: :admin?

  attr_accessor :send_email

  enum prefered_currency: {
    eur: 0,
    usd: 1,
    gbp: 2
  }

  after_create :send_password_email, if: -> (user) { user.send_email.to_i == 1 }
  after_save :send_connection_email, if: -> (user) { user.confirmed_at_changed? && user.confirmed_at_was.nil? }

  include RefSanitizer

  include Confirmable
  include ::UserPreferences
  include PreferencesCatalogSplits

  scope :for_reseller_id, ->(reseller_id) { where(reseller_id: reseller_id) }
  scope :from_customers_for_reseller_id, ->(reseller_id) { joins(:customer).where(customers: {reseller_id: reseller_id}) }

  def self.unities
    [
      %w(Km km),
      %w(Miles mi)
    ]
  end

  def admin?
    !reseller_id.nil?
  end

  def link_phone_number
    if self.url_click2call
      self.url_click2call
    else
      'tel:+{TEL}'
    end
  end

  def api_key_random
    self.api_key = SecureRandom.hex
  end

  def send_password_email
    locale = (self.locale) ? self.locale.to_sym : I18n.locale
    Planner::Application.config.delayed_job_use ? UserMailer.delay.password_message(self, locale) : UserMailer.password_message(self, locale).deliver_now
    self.update! confirmation_sent_at: Time.now
  end

  def send_connection_email
    locale = (self.locale) ? self.locale.to_sym : I18n.locale
    Planner::Application.config.delayed_job_use ? UserMailer.delay.connection_message(self, locale) : UserMailer.connection_message(self, locale).deliver_now
  end

  def save_export_settings(export_columns, skips, stops, format = "excel")
    self.update(export_settings: {
      export: export_columns,
      skips: skips,
      stops: stops,
      format: format
    })
  end

  private

  def set_default_time_zone
    self.time_zone = self.time_zone == 'UTC' ? I18n.t('default_time_zone') : self.time_zone
  end

  def set_time_zone
    set_default_time_zone if self.time_zone.blank?
  end

  def assign_defaults
    set_default_time_zone
    self.api_key || self.api_key_random
    # headers: normalized on validation (UserPreferences#normalize_user_preferences). Toolbar/forms come from Role or catalog defaults.
  end

  def assign_defaults_layer
    self.layer ||= if admin?
                     Layer.order(:id).find_by!(overlay: false)
                   else
                     customer && customer.profile.layers.order(:id).find_by!(overlay: false)
                   end
  end

  def role_matches_customer_reseller
    return if role_id.blank? || customer.blank?

    r = Role.find_by(id: role_id)
    return if r.blank?

    return if r.reseller_id == customer.reseller_id

    errors.add(:role_id, :invalid)
  end
end
