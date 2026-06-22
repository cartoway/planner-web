# frozen_string_literal: true

class AddUniqueIndexOnPlanningsRefAndCustomerId < ActiveRecord::Migration[6.1]
  INDEX_NAME = 'index_plannings_on_customer_id_and_lower_ref'

  class MigrationPlanning < ApplicationRecord
    self.table_name = 'plannings'
  end

  def up
    deduplicate_planning_refs
    execute <<~SQL.squish
      CREATE UNIQUE INDEX #{INDEX_NAME}
      ON plannings (customer_id, lower(ref))
      WHERE ref IS NOT NULL
    SQL
  end

  def down
    remove_index :plannings, name: INDEX_NAME
  end

  private

  def deduplicate_planning_refs
    say_with_time 'Renaming duplicate planning refs per customer (case insensitive)' do
      duplicate_ids = connection.select_values(<<~SQL)
        SELECT id
        FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY customer_id, lower(ref)
                   ORDER BY id
                 ) AS row_num
          FROM plannings
          WHERE ref IS NOT NULL
        ) ranked
        WHERE row_num > 1
        ORDER BY id
      SQL

      duplicate_ids.each do |planning_id|
        planning = MigrationPlanning.find(planning_id)
        new_ref = "#{planning.ref}#{Planning.duplicate_timestamp_suffix}"

        while MigrationPlanning.where(customer_id: planning.customer_id)
                               .where('lower(ref) = lower(?)', new_ref)
                               .where.not(id: planning.id)
                               .exists?
          new_ref += Planning.duplicate_timestamp_suffix
        end

        planning.update_columns(ref: new_ref, updated_at: Time.current)
      end
    end
  end
end
