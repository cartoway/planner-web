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
module Preferences
  # JSON options for data-drag-drop-options (see active_inactive_drag_drop.js). Single source for admin + self-service UIs.
  module DragDropOptions
    BASE = {
      minActiveItems: 0,
      itemSelector: '.draggable-item',
      orderDisplaySelector: '.item-order',
      textDisplaySelector: '.item-text'
    }.freeze

    module_function

    def headers_zone_options(param_prefix, zone_key)
      p = param_prefix.to_s
      z = zone_key.to_s
      BASE.merge(columns: [
        { containerSelector: ".headers-#{z}-tier-active .item-list", inputName: "#{p}[headers][#{z}][active][]" },
        { containerSelector: ".headers-#{z}-tier-hidden .item-list", inputName: "#{p}[headers][#{z}][hidden][]" }
      ])
    end

    def operations_three_zone_options(param_prefix, zone_key)
      p = param_prefix.to_s
      z = zone_key.to_s
      BASE.merge(showOrder: false, columns: [
        { containerSelector: '.operations-tier-active .item-list', inputName: "#{p}[operations][#{z}][]" },
        { containerSelector: '.operations-tier-disabled .item-list', inputName: "#{p}[operations][#{z}_disabled][]" },
        { containerSelector: '.operations-tier-hidden .item-list', inactive: true }
      ])
    end

    def forms_three_tier_options(param_prefix)
      p = param_prefix.to_s
      BASE.merge(showOrder: false, columns: [
        { containerSelector: '.forms-tier-active .item-list', inputName: "#{p}[forms_active][]", toggleTo: 1 },
        { containerSelector: '.forms-tier-disabled .item-list', inputName: "#{p}[forms_disabled][]", toggleTo: 2 },
        { containerSelector: '.forms-tier-hidden .item-list', inactive: true, toggleTo: 0 }
      ])
    end
  end
end
