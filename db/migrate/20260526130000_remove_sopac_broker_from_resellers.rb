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

class RemoveSopacBrokerFromResellers < ActiveRecord::Migration[6.1]
  def up
    return unless column_exists?(:resellers, :sopac_broker)

    remove_column :resellers, :sopac_broker
  end

  def down
    add_column :resellers, :sopac_broker, :jsonb, null: false, default: {} unless column_exists?(:resellers, :sopac_broker)
  end
end
