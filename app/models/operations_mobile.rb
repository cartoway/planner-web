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
# A blank document means every capability is none. Absent keys mean none.
class OperationsMobile
  CAPABILITIES = %w[
    routes.read_assigned
    routes.read_all
    routes.start
    stops.status_write
    stops.quantities_edit
    stops.proofs
    stops.transfer
    stops.reorder
    catalog.read
    catalog.edit
    history.read
    planning.edit
    tracking.share
  ].freeze
  LEVELS = %w[none visible usable].freeze
  ACCESS = %w[none usable].freeze

  def self.none
    { 'version' => 1, 'access' => 'none', 'capabilities' => {} }
  end

  def self.driver_default
    {
      'version' => 1,
      'access' => 'usable',
      'capabilities' => {
        'routes.read_assigned' => 'usable',
        'routes.read_all' => 'none',
        'routes.start' => 'usable',
        'stops.status_write' => 'usable',
        'stops.quantities_edit' => 'usable',
        'stops.proofs' => 'usable',
        'stops.transfer' => 'none',
        'stops.reorder' => 'none',
        'catalog.read' => 'none',
        'catalog.edit' => 'none',
        'history.read' => 'none',
        'planning.edit' => 'none',
        'tracking.share' => 'usable'
      }
    }
  end

  def self.solo_default
    {
      'version' => 1,
      'access' => 'usable',
      'capabilities' => CAPABILITIES.index_with { 'usable' }
    }
  end

  def self.coerce(value)
    hash = stringify(value)
    return none if hash.blank?

    hash
  end

  def self.read(value)
    hash = stringify(value)
    return none if hash.blank? || hash['version'].blank?

    hash
  end

  def self.access_usable?(value)
    read(value)['access'] == 'usable'
  end

  # Split capabilities into usable / visible / none (Active / Disabled / Hidden in the UI).
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
    errors << 'access' unless ACCESS.include?(hash['access'])
    caps = hash['capabilities']
    unless caps.is_a?(Hash)
      errors << 'capabilities'
      return errors
    end
    unknown = caps.keys - CAPABILITIES
    errors << 'unknown' if unknown.any?
    errors << 'level' if caps.any? { |_, level| !LEVELS.include?(level) }
    errors << 'extra' if (hash.keys - %w[version access capabilities]).any?
    errors
  end

  def self.stringify(value)
    return {} unless value.is_a?(Hash)

    value.deep_stringify_keys
  end
end
