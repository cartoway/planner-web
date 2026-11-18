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

# M4: email uniqueness lives on accounts. Two memberships may share an email.
# One account still cannot join the same customer or reseller twice.
class MoveEmailUniquenessToAccounts < ActiveRecord::Migration[6.1]
  def up
    remove_index :users, name: :index_users_on_email if index_exists?(:users, :email, name: :index_users_on_email)

    customer_dupes = select_all(<<~SQL)
      SELECT account_id, customer_id, array_agg(id ORDER BY id) AS ids
      FROM users
      WHERE customer_id IS NOT NULL
      GROUP BY account_id, customer_id
      HAVING COUNT(*) > 1
    SQL
    unless customer_dupes.empty?
      detail = customer_dupes.map { |row| "user ids #{row['ids']}" }.join('; ')
      raise "M4 aborted, duplicate memberships on the same customer: #{detail}"
    end

    reseller_dupes = select_all(<<~SQL)
      SELECT account_id, reseller_id, array_agg(id ORDER BY id) AS ids
      FROM users
      WHERE reseller_id IS NOT NULL AND customer_id IS NULL
      GROUP BY account_id, reseller_id
      HAVING COUNT(*) > 1
    SQL
    unless reseller_dupes.empty?
      detail = reseller_dupes.map { |row| "user ids #{row['ids']}" }.join('; ')
      raise "M4 aborted, duplicate admin memberships on the same reseller: #{detail}"
    end

    add_index :users, %i[account_id customer_id],
              unique: true,
              where: 'customer_id IS NOT NULL',
              name: 'index_users_on_account_id_and_customer_id'
    add_index :users, %i[account_id reseller_id],
              unique: true,
              where: 'reseller_id IS NOT NULL AND customer_id IS NULL',
              name: 'index_users_on_account_id_and_reseller_id'
  end

  def down
    remove_index :users, name: 'index_users_on_account_id_and_customer_id' if index_exists?(:users, %i[account_id customer_id], name: 'index_users_on_account_id_and_customer_id')
    remove_index :users, name: 'index_users_on_account_id_and_reseller_id' if index_exists?(:users, %i[account_id reseller_id], name: 'index_users_on_account_id_and_reseller_id')
    add_index :users, :email, unique: true, name: :index_users_on_email unless index_exists?(:users, :email, name: :index_users_on_email)
  end
end
