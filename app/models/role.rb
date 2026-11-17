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

# Reseller-defined label (name, ref, icon, color) plus toolbar + space permissions (planning_toolbar, spaces).
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
  before_validation :normalize_planning_toolbar_and_spaces_json
  before_validation :normalize_operations_mobile
  validate :operations_mobile_schema

  # Idempotent: returns existing or newly created system default role for this reseller.
  # with_lock on the reseller serializes find+create (no TOCTOU between find_by and create!).
  def self.create_default_permissions_role_for!(reseller)
    ref = default_permissions_role_ref
    reseller.with_lock do
      existing = Role.find_by(reseller_id: reseller.id, ref: ref)
      next existing if existing

      attrs = {
        name: I18n.t('admin.roles.default_permissions_role_name', default: 'Default permissions'),
        ref: ref,
        icon: default_new_reseller_role_icon,
        planning_toolbar: default_new_reseller_role_planning_toolbar_json,
        spaces: default_new_reseller_role_spaces_json,
        operations_mobile: OperationsMobile.solo_default
      }
      reseller.roles.create!(attrs)
    end
  rescue ActiveRecord::RecordNotUnique
    Role.find_by!(reseller_id: reseller.id, ref: ref)
  end

  # Idempotent Deliver-only system role (web spaces closed, operations_mobile usable).
  def self.create_default_driver_role_for!(reseller)
    ref = default_driver_role_ref
    reseller.with_lock do
      existing = Role.find_by(reseller_id: reseller.id, ref: ref)
      next existing if existing

      attrs = {
        name: 'Default driver',
        ref: ref,
        icon: default_driver_role_icon,
        planning_toolbar: Preferences::Catalog.normalize_planning_toolbar({}),
        spaces: default_driver_role_spaces_json,
        operations_mobile: OperationsMobile.driver_default
      }
      reseller.roles.create!(attrs)
    end
  rescue ActiveRecord::RecordNotUnique
    Role.find_by!(reseller_id: reseller.id, ref: ref)
  end

  class << self
    def default_permissions_role_ref
      raw = default_role_yaml_hash['ref']
      if raw.nil? || raw.to_s.strip.empty?
        raise ArgumentError, I18n.t('activerecord.errors.models.role.default_role_config_missing_ref')
      end

      raw.to_s.strip
    end

    def default_driver_role_ref
      raw = default_driver_role_yaml_hash['ref']
      if raw.nil? || raw.to_s.strip.empty?
        raise ArgumentError, I18n.t('activerecord.errors.models.role.default_driver_role_config_missing_ref')
      end

      raw.to_s.strip
    end

    def default_new_reseller_role_icon
      raw = default_role_yaml_hash['icon']
      FontAwesome.normalized_fa_icon_token(raw)
    end

    def default_driver_role_icon
      raw = default_driver_role_yaml_hash['icon']
      FontAwesome.normalized_fa_icon_token(raw.presence || 'fa-dolly')
    end

    def default_driver_role_spaces_json
      Preferences::Catalog.normalize_spaces(
        Preferences::Catalog::WEB_SPACE_KEYS.index_with { |_k| { 'visible' => false, 'usable' => false } }.merge(
          'operations_mobile' => { 'visible' => true, 'usable' => true }
        )
      )
    end

    private

    def default_role_yaml_hash
      dr = Preferences::Catalog::ConfigSeeds.roles_hash['default_role']
      dr.is_a?(Hash) ? dr : {}
    end

    def default_driver_role_yaml_hash
      dr = Preferences::Catalog::ConfigSeeds.roles_hash['default_driver_role']
      dr.is_a?(Hash) ? dr : {}
    end

    def default_new_reseller_role_planning_toolbar_json
      Preferences::Catalog.baseline_role_planning_toolbar_json.deep_dup
    end

    def default_new_reseller_role_spaces_json
      Preferences::Catalog.baseline_role_spaces_json.deep_dup
    end
  end

  private

  def nilify_blank_ref
    self.ref = ref&.strip.presence
  end

  def read_headers_hash
    {}
  end

  def read_planning_toolbar_hash
    planning_toolbar.is_a?(Hash) ? planning_toolbar.deep_stringify_keys : {}
  end

  def read_spaces_hash
    spaces.is_a?(Hash) ? spaces.deep_stringify_keys : {}
  end

  def normalize_planning_toolbar_and_spaces_json
    self.planning_toolbar = Preferences::Catalog.normalize_planning_toolbar(read_planning_toolbar_hash)
    self.spaces = Preferences::Catalog.normalize_spaces(read_spaces_hash)
  end

  def normalize_operations_mobile
    self.operations_mobile = OperationsMobile.coerce(operations_mobile)
  end

  def operations_mobile_schema
    return if OperationsMobile.errors_for(operations_mobile).empty?

    errors.add(:operations_mobile, :invalid)
  end
end
