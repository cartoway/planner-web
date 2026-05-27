# Copyright © Mapotempo, 2015
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
require 'sanitize'

class Reseller < ApplicationRecord
  has_many :customers, inverse_of: :reseller, autosave: true, dependent: :delete_all
  has_many :roles, dependent: :destroy
  # Column remains default_role_id; name cannot be :default_role (conflicts with ActiveRecord::Base#default_role).
  belongs_to :new_user_default_role, class_name: 'Role', foreign_key: :default_role_id, optional: true
  belongs_to :default_profile, class_name: 'Profile', optional: true
  belongs_to :default_router, class_name: 'Router', optional: true

  after_commit :create_default_permissions_role, on: :create

  nilify_blanks
  auto_strip_attributes :host, :name, :welcome_url, :help_url, :contact_url, :website_url
  validates :host, presence: true
  validates :name, presence: true
  validate :new_user_default_role_belongs_to_reseller
  validate :default_profile_and_router_pair
  validate :default_router_in_default_profile

  mount_uploader :logo_large, Admin::LogoLargeUploader
  mount_uploader :logo_small, Admin::LogoSmallUploader
  mount_uploader :favicon, Admin::FaviconUploader

  after_save :invalidate_cache

  def help_search_url
    nil
  end

  # Pre-fill profile / router on new customers when reseller defaults are configured.
  def apply_defaults_to_customer(customer)
    return customer unless customer.new_record?

    if customer.profile_id.blank? && default_profile_id.present?
      customer.profile_id = default_profile_id
    end

    if customer.router_id.blank? && default_router_id.present?
      customer.router_id = default_router_id
      customer.router_dimension = default_router_dimension if customer.router_dimension.blank?
    end

    customer
  end

  def default_router_dimension
    router = default_router
    return 'time' if router&.time?
    return 'distance' if router&.distance?

    'time'
  end

  private

  def create_default_permissions_role
    return if @_default_permissions_role_seeded

    succeeded = false
    begin
      @_default_permissions_role_seeded = true
      role = Role.create_default_permissions_role_for!(self)
      update_column(:default_role_id, role.id) if role.present? && default_role_id != role.id
      # A newly created reseller must only carry the system default role; remove any extras
      # (duplicate callbacks, orphan rows, or mis-association) without touching other resellers.
      Role.where(reseller_id: id).where.not(id: role.id).delete_all
      succeeded = true
    ensure
      @_default_permissions_role_seeded = false unless succeeded
    end
  end

  def new_user_default_role_belongs_to_reseller
    return if default_role_id.blank?
    return if new_user_default_role&.reseller_id == id

    errors.add(:default_role_id, :invalid)
  end

  def default_profile_and_router_pair
    profile_set = default_profile_id.present?
    router_set = default_router_id.present?
    return if profile_set == router_set

    errors.add(:base, :default_profile_and_router_mismatch)
  end

  def default_router_in_default_profile
    return if default_profile_id.blank? || default_router_id.blank?
    return if default_profile.routers.exists?(id: default_router_id)

    errors.add(:default_router_id, :invalid)
  end

  def invalidate_cache
    ResellerCacheService.invalidate(host)
  end
end
