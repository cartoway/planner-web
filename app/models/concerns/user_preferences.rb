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

# JSON on User: headers only (layout). Toolbar + space permissions: Role.planning_toolbar / Role.spaces when a role is set;
# otherwise catalog defaults (see ::Preferences::Catalog).
module UserPreferences
  extend ActiveSupport::Concern
  include UserPreferences::DestinationsIndex

  included do
    before_validation :normalize_user_preferences
  end

  def operation_segment_control(zone, segment_id)
    id = segment_id.to_s
    z = effective_read_planning_toolbar_hash[zone.to_s]
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

  def space_entry(resource)
    key = resource.to_s
    return nil unless ::Preferences::Catalog::SPACE_KEYS.include?(key)

    effective_read_spaces_hash[key]
  end

  def space_visible?(resource)
    entry = space_entry(resource)
    return true if entry.nil?

    ::Preferences::Catalog.truthy?(entry['visible'])
  end

  def space_usable?(resource)
    return false unless space_visible?(resource)

    entry = space_entry(resource)
    return true if entry.nil?

    ::Preferences::Catalog.truthy?(entry['usable'])
  end

  def space_action_control(resource, action_id)
    entry = space_entry(resource)
    return default_segment_control if entry.blank?

    actions = entry['actions'].is_a?(Hash) ? entry['actions'].stringify_keys : {}
    sc = actions['segment_controls'].is_a?(Hash) ? actions['segment_controls'].stringify_keys : {}
    raw = sc[action_id.to_s]
    return default_segment_control if raw.nil? || !raw.is_a?(Hash)

    raw.stringify_keys
  end

  def space_action_visible?(resource, action_id)
    return false unless space_visible?(resource)

    v = space_action_control(resource, action_id)['visible']
    return false if v.nil?

    ::Preferences::Catalog.truthy?(v)
  end

  def space_action_usable?(resource, action_id)
    return false unless space_usable?(resource)
    return false unless space_action_visible?(resource, action_id)

    u = space_action_control(resource, action_id)['usable']
    return false if u.nil?

    ::Preferences::Catalog.truthy?(u)
  end

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
    sl = hp['stop_list'].presence || hp['stop_display']
    base['stop_list'] = sl if sl.present?
    dl = hp['destinations_list'].presence
    base['destinations_list'] = dl if dl.present?
    if hp.key?('destinations_index')
      current = ::Preferences::Catalog::Headers.normalize_destinations_index_config(base['destinations_index'])
      raw_destinations_index = hp['destinations_index']
      base['destinations_index'] =
        if raw_destinations_index.is_a?(Hash)
          current.merge(raw_destinations_index.deep_stringify_keys.slice('version', 'per_page'))
        else
          current.merge('version' => Array(raw_destinations_index).last)
        end
    end
    self.headers = ::Preferences::Catalog.normalize_headers(base, customer: customer)
  end

  def stop_list_active_field_ids
    z = read_headers_hash['stop_list'].presence || read_headers_hash['stop_display']
    ::Preferences::Catalog::StopList.normalize_zone(z)['active']
  end

  private

  def normalize_user_preferences
    self.headers = ::Preferences::Catalog.normalize_headers(read_headers_hash, customer: customer)
  end

  def default_segment_control
    ::Preferences::Catalog::DEFAULT_BOOL.slice('visible', 'usable').dup
  end

  def read_headers_hash
    headers.is_a?(Hash) ? headers.stringify_keys : {}
  end

  def read_planning_toolbar_hash
    raw = if permissions_from_role?
            role.planning_toolbar
          else
            ::Preferences::Catalog.no_role_planning_toolbar_seed_hash
          end
    ::Preferences::Catalog.normalize_planning_toolbar(raw.is_a?(Hash) ? raw : {}).deep_stringify_keys
  end

  def read_spaces_hash
    raw = if permissions_from_role?
            role.spaces
          else
            ::Preferences::Catalog.no_role_spaces_seed_hash
          end
    ::Preferences::Catalog.normalize_spaces(raw.is_a?(Hash) ? raw : {}).deep_stringify_keys
  end

  def effective_read_planning_toolbar_hash
    read_planning_toolbar_hash
  end

  def effective_read_spaces_hash
    read_spaces_hash
  end

  def permissions_from_role?
    return false if respond_to?(:admin?) && admin?

    role_id.present? && role.present?
  end
end
