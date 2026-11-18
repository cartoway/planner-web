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

# M1: one Account per User. Password digest is copied here so a database
# restored from this migration already has identical credentials (criterion 1).
# Emails that differ only by case abort the migration and list user ids.
class CreateAccounts < ActiveRecord::Migration[6.1]
  def up
    create_table :accounts do |t|
      t.uuid :uid, null: false
      t.string :email
      t.string :encrypted_password, null: false, default: ''
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.integer :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip
      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email
      t.string :name
      t.string :phone
      t.string :locale
      t.string :time_zone
      t.datetime :anonymized_at
      t.bigint :last_user_id
      t.bigint :backfill_user_id
      t.timestamps
    end
    add_index :accounts, :uid, unique: true
    add_index :accounts, :backfill_user_id, unique: true

    collisions = select_all(<<~SQL)
      SELECT LOWER(btrim(email)) AS email_key, array_agg(id ORDER BY id) AS ids
      FROM users
      WHERE email IS NOT NULL AND btrim(email) <> ''
      GROUP BY LOWER(btrim(email))
      HAVING COUNT(*) > 1
    SQL
    unless collisions.empty?
      detail = collisions.map { |row| "#{row['email_key']} user ids #{row['ids']}" }.join('; ')
      raise "M1 aborted, email case collisions: #{detail}"
    end

    execute <<~SQL
      INSERT INTO accounts (
        uid, email, encrypted_password, reset_password_token, reset_password_sent_at,
        remember_created_at, sign_in_count, current_sign_in_at, last_sign_in_at,
        current_sign_in_ip, last_sign_in_ip, confirmation_token, confirmed_at,
        confirmation_sent_at, locale, time_zone, backfill_user_id, created_at, updated_at
      )
      SELECT
        (md5(random()::text || clock_timestamp()::text || users.id::text))::uuid,
        NULLIF(btrim(email), ''),
        encrypted_password,
        reset_password_token,
        reset_password_sent_at,
        remember_created_at,
        COALESCE(sign_in_count, 0),
        current_sign_in_at,
        last_sign_in_at,
        current_sign_in_ip,
        last_sign_in_ip,
        confirmation_token,
        confirmed_at,
        confirmation_sent_at,
        locale,
        time_zone,
        id,
        COALESCE(created_at, NOW()),
        COALESCE(updated_at, NOW())
      FROM users
    SQL

    add_index :accounts, 'LOWER(email)', unique: true,
                                         where: "email IS NOT NULL AND btrim(email) <> ''",
                                         name: 'index_accounts_on_lower_email'

    add_reference :users, :account, foreign_key: true, index: true
    execute <<~SQL
      UPDATE users
      SET account_id = accounts.id
      FROM accounts
      WHERE accounts.backfill_user_id = users.id
    SQL
    change_column_null :users, :account_id, false

    add_column :users, :status, :string, null: false, default: 'active'
    add_column :users, :relationship, :string, null: false, default: 'employee'
    add_column :users, :label, :string
    add_column :users, :phone, :string

    remove_column :accounts, :backfill_user_id
    add_foreign_key :accounts, :users, column: :last_user_id, on_delete: :nullify
  end

  def down
    remove_foreign_key :accounts, column: :last_user_id if foreign_key_exists?(:accounts, column: :last_user_id)
    remove_column :users, :phone if column_exists?(:users, :phone)
    remove_column :users, :label if column_exists?(:users, :label)
    remove_column :users, :relationship if column_exists?(:users, :relationship)
    remove_column :users, :status if column_exists?(:users, :status)
    remove_reference :users, :account, foreign_key: true, index: true if column_exists?(:users, :account_id)
    drop_table :accounts if table_exists?(:accounts)
  end
end
