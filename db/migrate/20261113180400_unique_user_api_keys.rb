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

# M5: api_key stays on the membership and becomes unique.
# Duplicate keys abort the migration. Ids are listed; the keys are not.
class UniqueUserApiKeys < ActiveRecord::Migration[6.1]
  def up
    dupes = select_all(<<~SQL)
      SELECT array_agg(id ORDER BY id) AS ids
      FROM users
      GROUP BY api_key
      HAVING COUNT(*) > 1
    SQL
    unless dupes.empty?
      detail = dupes.map { |row| row['ids'] }.join('; ')
      raise "M5 aborted, duplicate api_key on user ids: #{detail}"
    end

    remove_index :users, name: :index_users_on_api_key if index_exists?(:users, :api_key, name: :index_users_on_api_key)
    add_index :users, :api_key, unique: true, name: :index_users_on_api_key
  end

  def down
    remove_index :users, name: :index_users_on_api_key if index_exists?(:users, :api_key, unique: true, name: :index_users_on_api_key)
    add_index :users, :api_key, name: :index_users_on_api_key unless index_exists?(:users, :api_key, name: :index_users_on_api_key)
  end
end
