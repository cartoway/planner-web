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
  validates :ref, uniqueness: { scope: :reseller_id }, if: -> { ref.present? }
  validates_format_of :color, with: /\A(|\#[A-Fa-f0-9]{6})\Z/, allow_blank: true
  validates_inclusion_of :icon, in: FontAwesome::ICONS_TABLE, allow_blank: true,
                                message: ->(*_) { I18n.t('activerecord.errors.models.role.icon_unknown') }

  before_validation :nilify_blank_ref
  before_validation :normalize_operations_and_forms_json

  # Idempotent: returns existing or newly created system default role for this reseller.
  # with_lock on the reseller serializes find+create (no TOCTOU between find_by and create!).
  def self.create_default_permissions_role_for!(reseller)
    ref = default_permissions_role_ref
    reseller.with_lock do
      reseller.roles.find_by(ref: ref) || reseller.roles.create!(
        name: I18n.t('admin.roles.default_permissions_role_name', default: 'Default permissions'),
        ref: ref,
        icon: default_new_reseller_role_icon,
        operations: default_new_reseller_role_operations_json,
        forms: default_new_reseller_role_forms_json
      )
    end
  rescue ActiveRecord::RecordNotUnique
    reseller.roles.find_by!(ref: ref)
  end

  class << self

    # System role created for each reseller (see Reseller#create_default_permissions_role).
    # ref / icon / operations / forms are read from config/default_new_reseller_role.yml (+default_role+).
    def default_permissions_role_ref
      raw = default_role_yaml_hash['ref']
      if raw.nil? || raw.to_s.strip.empty?
        raise ArgumentError, I18n.t('activerecord.errors.models.role.default_role_config_missing_ref')
      end

      raw.to_s.strip
    end

    def default_new_reseller_role_icon
      raw = default_role_yaml_hash['icon']
      FontAwesome.normalized_fa_icon_token(raw)
    end

    private

    # Slice of config/default_new_reseller_role.yml under +default_role+ (ref, icon, operations, forms).
    def default_role_yaml_hash
      dr = Preferences::Catalog::ConfigSeeds.roles_hash['default_role']
      dr.is_a?(Hash) ? dr : {}
    end

    # Normalized operations JSON for the reseller system role (+default_role.operations+ in YAML).
    def default_new_reseller_role_operations_json
      Preferences::Catalog.baseline_role_operations_json.deep_dup
    end

    # Normalized forms JSON for the reseller system role (+default_role.forms+ in YAML).
    def default_new_reseller_role_forms_json
      Preferences::Catalog.baseline_role_forms_json.deep_dup
    end
  end

  private

  # Aligns with DB partial unique index (reseller_id, ref) WHERE ref IS NOT NULL: store NULL, not "".
  def nilify_blank_ref
    self.ref = ref&.strip.presence
  end

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
