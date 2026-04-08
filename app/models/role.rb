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

# Reseller-defined label (name, ref, icon, color) plus toolbar + form permissions (operations, forms).
# Header layout stays on User only.
class Role < ApplicationRecord
  include PreferencesCatalogSplits

  belongs_to :reseller
  has_many :users, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :reseller_id }
  validates :ref, uniqueness: { scope: :reseller_id }, allow_blank: true
  validates_format_of :color, with: /\A(|\#[A-Fa-f0-9]{6})\Z/, allow_blank: true
  validates_inclusion_of :icon, in: FontAwesome::ICONS_TABLE, allow_blank: true,
                                message: ->(*_) { I18n.t('activerecord.errors.models.role.icon_unknown') }

  before_validation :normalize_operations_and_forms_json

  private

  # Unused for Role UI (no header drag-drop); required if header_blocks_split is ever called.
  def read_headers_hash
    {}
  end

  def read_operations_hash
    operations.is_a?(Hash) ? operations.deep_stringify_keys : {}
  end

  def read_forms_hash
    forms.is_a?(Hash) ? forms.stringify_keys : {}
  end

  def normalize_operations_and_forms_json
    self.operations = Preferences::Catalog.normalize_operations(read_operations_hash)
    self.forms = Preferences::Catalog.normalize_forms(read_forms_hash)
  end
end
