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

  after_create :create_default_permissions_role

  nilify_blanks
  auto_strip_attributes :host, :name, :welcome_url, :help_url, :contact_url, :website_url
  validates :host, presence: true
  validates :name, presence: true
  validate :new_user_default_role_belongs_to_reseller

  mount_uploader :logo_large, Admin::LogoLargeUploader
  mount_uploader :logo_small, Admin::LogoSmallUploader
  mount_uploader :favicon, Admin::FaviconUploader

  after_save :invalidate_cache

  def help_search_url
    nil
  end

  private

  def create_default_permissions_role
    role = Role.create_default_permissions_role_for!(self)
    update_column(:default_role_id, role.id) if role.present?
  end

  def new_user_default_role_belongs_to_reseller
    return if default_role_id.blank?
    return if new_user_default_role&.reseller_id == id

    errors.add(:default_role_id, :invalid)
  end

  def invalidate_cache
    ResellerCacheService.invalidate(host)
  end
end
