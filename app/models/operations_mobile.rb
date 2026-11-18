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

# Closed list of mobile capabilities (operations-mobile.schema.json v1).
# Access gate lives in Role.spaces['operations_mobile']; this JSON is capabilities only.
# routes.read_assigned is implied whenever the space is usable (not admin-configurable).
class OperationsMobile
  CAPABILITIES = %w[
    routes.read_all
    routes.start
    stops.status_write
    stops.quantities_edit
    stops.proofs
    stops.transfer
    stops.reorder
  ].freeze
  IMPLIED_WHEN_ACCESS = { 'routes.read_assigned' => 'usable' }.freeze
  LEVELS = %w[none visible usable].freeze

  def self.none
    { 'version' => 1, 'capabilities' => {} }
  end

  def self.driver_default
    {
      'version' => 1,
      'capabilities' => {
        'routes.read_all' => 'none',
        'routes.start' => 'usable',
        'stops.status_write' => 'usable',
        'stops.quantities_edit' => 'usable',
        'stops.proofs' => 'usable',
        'stops.transfer' => 'none',
        'stops.reorder' => 'none'
      }
    }
  end

  def self.solo_default
    {
      'version' => 1,
      'capabilities' => CAPABILITIES.index_with { 'usable' }
    }
  end

  # Build a capabilities document from admin form params (usable / visible arrays).
  def self.from_form(usable:, visible:)
    usable_keys = Array(usable).map(&:to_s) & CAPABILITIES
    visible_keys = (Array(visible).map(&:to_s) & CAPABILITIES) - usable_keys
    caps = CAPABILITIES.index_with do |key|
      if usable_keys.include?(key)
        'usable'
      elsif visible_keys.include?(key)
        'visible'
      else
        'none'
      end
    end
    { 'version' => 1, 'capabilities' => caps }
  end

  def self.coerce(value)
    hash = stringify(value)
    return none if hash.blank?

    caps = hash['capabilities']
    caps = {} unless caps.is_a?(Hash)
    { 'version' => 1, 'capabilities' => caps.slice(*CAPABILITIES) }
  end

  def self.read(value, access_usable: false)
    hash = stringify(value)
    return none if hash.blank? || hash['version'].blank?

    caps = hash['capabilities']
    caps = caps.is_a?(Hash) ? caps.slice(*CAPABILITIES) : {}
    caps = caps.merge(IMPLIED_WHEN_ACCESS) if access_usable
    hash.merge('capabilities' => caps).except('access')
  end

  # Split configurable capabilities into usable / visible / none (Active / Disabled / Hidden).
  def self.capability_three_way_split(value)
    caps = read(value)['capabilities']
    caps = {} unless caps.is_a?(Hash)
    usable = []
    visible = []
    none = []
    CAPABILITIES.each do |key|
      case caps[key].presence || 'none'
      when 'usable' then usable << key
      when 'visible' then visible << key
      else none << key
      end
    end
    [usable, visible, none]
  end

  def self.errors_for(value)
    hash = stringify(value)
    return ['invalid'] unless hash.is_a?(Hash)

    errors = []
    errors << 'version' unless hash['version'] == 1
    caps = hash['capabilities']
    unless caps.is_a?(Hash)
      errors << 'capabilities'
      return errors
    end
    unknown = caps.keys - CAPABILITIES
    errors << 'unknown' if unknown.any?
    errors << 'level' if caps.any? { |_, level| !LEVELS.include?(level) }
    errors << 'extra' if (hash.keys - %w[version capabilities]).any?
    errors
  end

  def self.stringify(value)
    return {} unless value.is_a?(Hash)

    value.deep_stringify_keys
  end
end
