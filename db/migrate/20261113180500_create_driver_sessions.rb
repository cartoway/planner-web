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

# M8: devices and tokens for the driver app. Nothing to backfill.
class CreateDriverSessions < ActiveRecord::Migration[6.1]
  def change
    create_table :account_devices do |t|
      t.references :account, null: false, foreign_key: true
      t.string :installation_id, null: false
      t.string :platform, null: false
      t.string :app_version
      t.string :os_version
      t.string :locale
      t.string :push_provider
      t.string :push_token
      t.string :notifications_permission
      t.datetime :last_seen_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :account_devices, %i[account_id installation_id], unique: true, name: 'index_account_devices_on_account_and_installation'

    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account_device, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :revoked_reason
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :user_sessions, :token_digest, unique: true

    create_table :account_sessions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :account_device, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :account_sessions, :token_digest, unique: true

    create_table :workspace_switch_events do |t|
      t.references :account, null: false, foreign_key: true
      t.bigint :from_user_id
      t.bigint :to_user_id
      t.string :channel, null: false
      t.string :result, null: false
      t.datetime :created_at, null: false
    end
    add_index :workspace_switch_events, :created_at

    add_column :roles, :operations_mobile, :jsonb, null: false, default: {}
  end
end
