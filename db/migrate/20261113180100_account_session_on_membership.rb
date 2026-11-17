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

# M2: the Devise session stays on the membership. session_token is null until
# a suspension, so existing cookies keep the same authenticatable salt.
# A blank users.time_zone means "use the account zone".
class AccountSessionOnMembership < ActiveRecord::Migration[6.1]
  def up
    add_column :users, :session_token, :string
    change_column_null :users, :time_zone, true
  end

  def down
    change_column_null :users, :time_zone, false, 'UTC'
    remove_column :users, :session_token
  end
end
