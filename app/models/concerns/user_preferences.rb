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

# JSON on User: headers only (layout). Toolbar + form permissions: Role.operations / Role.forms when a role is set;
# otherwise catalog defaults (see ::Preferences::Catalog).
module UserPreferences
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_user_preferences
  end

  def operation_segment_control(zone, segment_id)
    id = segment_id.to_s
    z = effective_read_operations_hash[zone.to_s]
    return default_segment_control if z.blank?

    sc = z['segment_controls']
    sc = sc.is_a?(Hash) ? sc.stringify_keys : {}
    raw = sc[id]
    return default_segment_control if raw.nil?
    return default_segment_control unless raw.is_a?(Hash)

    raw.stringify_keys
  end

  def operation_segment_usable?(zone, segment_id)
    return false unless operation_segment_visible?(zone, segment_id)

    u = operation_segment_control(zone, segment_id)['usable']
    return false if u.nil?

    ::Preferences::Catalog.truthy?(u)
  end

  def operation_segment_visible?(zone, segment_id)
    v = operation_segment_control(zone, segment_id)['visible']
    return false if v.nil?

    ::Preferences::Catalog.truthy?(v)
  end

  def operation_segment_customizable?(zone, segment_id)
    ::Preferences::Catalog.truthy?(operation_segment_control(zone, segment_id)['customizable'])
  end

  def form_policy(resource)
    key = resource.to_s
    unless ::Preferences::Catalog::FORM_RESOURCES.include?(key)
      return { 'visible' => true, 'usable' => true, 'create' => true, 'update' => true }
    end

    f = effective_read_forms_hash[key] || {}
    vis = ::Preferences::Catalog.truthy?(f.fetch('visible', true))
    use = ::Preferences::Catalog.truthy?(f.fetch('usable', true))
    can_mutate = vis && use
    {
      'visible' => vis,
      'usable' => use,
      'create' => can_mutate,
      'update' => can_mutate
    }
  end

  def form_visible?(resource)
    form_policy(resource)['visible']
  end

  def form_create?(resource)
    form_policy(resource)['create']
  end

  def form_update?(resource)
    form_policy(resource)['update']
  end

  # Self-service: header block order only (headers JSON on User).
  def apply_self_service_display_ui!(headers_params: nil)
    return if headers_params.blank?

    hp = if headers_params.respond_to?(:to_unsafe_h)
           headers_params.to_unsafe_h.deep_stringify_keys
         else
           headers_params.deep_stringify_keys
         end
    base = read_headers_hash.dup
    base['planning'] = hp['planning'] if hp['planning'].present?
    base['route'] = hp['route'] if hp['route'].present?
    self.headers = ::Preferences::Catalog.normalize_headers(base)
  end

  private

  def normalize_user_preferences
    self.headers = ::Preferences::Catalog.normalize_headers(read_headers_hash)
  end

  def default_segment_control
    ::Preferences::Catalog::DEFAULT_BOOL.slice('visible', 'customizable', 'usable').dup
  end

  def read_headers_hash
    headers.is_a?(Hash) ? headers.stringify_keys : {}
  end

  # Effective toolbar JSON (no users.operations column; role or catalog defaults).
  def read_operations_hash
    raw = permissions_from_role? ? role.operations : {}
    ::Preferences::Catalog.normalize_operations(raw.is_a?(Hash) ? raw : {}).deep_stringify_keys
  end

  # Effective forms policy JSON (no users.forms column; role or catalog defaults).
  def read_forms_hash
    raw = permissions_from_role? ? role.forms : {}
    ::Preferences::Catalog.normalize_forms(raw.is_a?(Hash) ? raw : {}).stringify_keys
  end

  def effective_read_operations_hash
    read_operations_hash
  end

  def effective_read_forms_hash
    read_forms_hash
  end

  def permissions_from_role?
    return false if respond_to?(:admin?) && admin?

    role_id.present? && role.present?
  end
end
