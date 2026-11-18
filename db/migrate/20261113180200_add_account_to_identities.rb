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

# M3: OmniAuth identities belong to the Account. user_id stays so existing
# links keep working.
class AddAccountToIdentities < ActiveRecord::Migration[6.1]
  def up
    add_reference :identities, :account, foreign_key: true, index: true
    execute <<~SQL
      UPDATE identities
      SET account_id = users.account_id
      FROM users
      WHERE users.id = identities.user_id
    SQL
    orphans = select_value('SELECT COUNT(*) FROM identities WHERE account_id IS NULL')
    raise "M3 aborted, #{orphans} identities without an account" if orphans.to_i.positive?

    change_column_null :identities, :account_id, false
  end

  def down
    remove_reference :identities, :account, foreign_key: true, index: true
  end
end
