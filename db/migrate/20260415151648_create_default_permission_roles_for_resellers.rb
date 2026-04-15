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

class CreateDefaultPermissionRolesForResellers < ActiveRecord::Migration[6.1]
  def up
    say_with_time 'Creating default permission role for each reseller' do
      Reseller.find_each do |reseller|
        Role.create_default_permissions_role_for!(reseller)
      end
    end

    say_with_time 'Assigning default role to users with no role' do
      default_ref = Role.default_permissions_role_ref
      User.where(role_id: nil).includes(:customer).find_each do |user|
        # Match User#role_matches_customer_reseller: role must belong to the same reseller as the customer.
        reseller_id = user.customer_id.present? ? user.customer&.reseller_id : user.reseller_id
        next if reseller_id.blank?

        role_id = Role.where(reseller_id: reseller_id, ref: default_ref).pick(:id)
        next if role_id.blank?

        user.update_columns(role_id: role_id, updated_at: Time.current)
      end
    end

    add_reference :resellers, :default_role, foreign_key: { to_table: :roles, on_delete: :nullify }, index: true

    say_with_time 'Backfill resellers.default_role_id from system default role' do
      Reseller.reset_column_information
      default_ref = Role.default_permissions_role_ref
      Reseller.find_each do |reseller|
        role_id = Role.where(reseller_id: reseller.id, ref: default_ref).pick(:id)
        reseller.update_column(:default_role_id, role_id) if role_id
      end
    end
  end

  def down
    remove_reference :resellers, :default_role, foreign_key: { to_table: :roles }, index: true
    Role.where(ref: Role.default_permissions_role_ref).find_each(&:destroy!)
  end
end
