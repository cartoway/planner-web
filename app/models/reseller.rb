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

  nilify_blanks
  auto_strip_attributes :host, :name, :welcome_url, :help_url, :contact_url, :website_url
  validates :host, presence: true
  validates :name, presence: true

  mount_uploader :logo_large, Admin::LogoLargeUploader
  mount_uploader :logo_small, Admin::LogoSmallUploader
  mount_uploader :favicon, Admin::FaviconUploader

  def help_search_url
    nil
  end
end
