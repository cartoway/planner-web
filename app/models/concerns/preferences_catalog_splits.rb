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

# Shared helpers for admin drag-and-drop UIs over JSONB headers / operations / forms.
# Requires #read_operations_hash and #read_forms_hash (see Role, UserPreferences).
module PreferencesCatalogSplits
  extend ActiveSupport::Concern

  # Ordered visible header block ids (see headers zone { active, hidden }).
  def header_block_order(kind)
    header_blocks_split(kind).first
  end

  # [active_ids, hidden_ids] for admin header DnD (headers.planning / headers.route).
  def header_blocks_split(kind)
    k = kind.to_s
    allowed = k == 'route' ? Preferences::Catalog::HEADER_ROUTE : Preferences::Catalog::HEADER_PLANNING
    z = read_headers_hash[k]
    h = Preferences::Catalog.normalize_header_zone(z, allowed)
    [h['active'], h['hidden']]
  end

  # Active | disabled | hidden toolbar item ids for admin operations DnD (segment_controls visible + usable).
  def operations_tier_split(zone)
    z = zone.to_s
    allowed = case z
              when 'route' then Preferences::Catalog::OPERATION_GROUPS_ROUTE
              when 'stop' then Preferences::Catalog::OPERATION_GROUPS_STOP
              else Preferences::Catalog::OPERATION_GROUPS_PLANNING
              end
    ops = case z
          when 'stop'
            Preferences::Catalog.normalize_stop_zone(read_operations_hash['stop'])
          else
            h = read_operations_hash[z] || {}
            h.is_a?(Hash) ? h.stringify_keys : {}
          end
    order = Array(ops['segments']).map(&:to_s)
    controls = ops['segment_controls'].is_a?(Hash) ? ops['segment_controls'].stringify_keys : {}

    bucket = lambda do |id|
      c = controls[id].is_a?(Hash) ? controls[id].stringify_keys : {}
      # Defaults must match Operations.normalize_zone missing segment_controls (visible, not usable).
      vis = Preferences::Catalog.truthy?(c.fetch('visible', Preferences::Catalog::Operations::NORMALIZE_SEGMENT_VISIBLE_DEFAULT))
      use = Preferences::Catalog.truthy?(c.fetch('usable', Preferences::Catalog::Operations::NORMALIZE_SEGMENT_USABLE_DEFAULT))
      return :hidden unless vis

      use ? :active : :disabled
    end

    active = []
    disabled = []
    hidden = []
    seen = {}

    order.each do |id|
      next unless allowed.include?(id)
      next if seen[id]

      seen[id] = true
      case bucket.call(id)
      when :active then active << id
      when :disabled then disabled << id
      else hidden << id
      end
    end

    allowed.each do |id|
      next if seen[id]

      seen[id] = true
      case bucket.call(id)
      when :active then active << id
      when :disabled then disabled << id
      else hidden << id
      end
    end

    [active, disabled, hidden]
  end

  # Active | disabled | hidden form resource ids (visible + usable, same semantics as operations tiers).
  def forms_resources_three_way_split
    allowed = Preferences::Catalog::FORM_RESOURCES
    h = Preferences::Catalog.normalize_forms(read_forms_hash)
    ordered = []
    h.each_key { |k| ordered << k if allowed.include?(k) }
    allowed.each { |k| ordered << k unless ordered.include?(k) }

    active = []
    disabled = []
    hidden = []

    ordered.each do |id|
      e = h[id].is_a?(Hash) ? h[id].stringify_keys : {}
      vis = Preferences::Catalog.truthy?(e.fetch('visible', Preferences::Catalog::Forms::NORMALIZE_FORM_VISIBLE_DEFAULT))
      use = Preferences::Catalog.truthy?(e.fetch('usable', Preferences::Catalog::Forms::NORMALIZE_FORM_USABLE_DEFAULT))

      if !vis
        hidden << id
      elsif use
        active << id
      else
        disabled << id
      end
    end

    [active, disabled, hidden]
  end
end
