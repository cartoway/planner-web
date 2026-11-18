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

# Reseller default driver role (seeded), optional per-customer override.
class AddDefaultDriverRole < ActiveRecord::Migration[6.1]
  def up
    add_reference :resellers, :default_driver_role, foreign_key: { to_table: :roles, on_delete: :nullify }, index: true
    add_reference :customers, :default_driver_role, foreign_key: { to_table: :roles, on_delete: :nullify }, index: true

    say_with_time 'seed default driver roles for existing resellers' do
      Reseller.reset_column_information
      Reseller.find_each do |reseller|
        role = Role.create_default_driver_role_for!(reseller)
        next unless role
        next if reseller.default_driver_role_id == role.id

        reseller.update_column(:default_driver_role_id, role.id)
      end
    end
  end

  def down
    remove_reference :customers, :default_driver_role, foreign_key: true
    remove_reference :resellers, :default_driver_role, foreign_key: true
  end
end
