# frozen_string_literal: true

class AddUniqueIndexOnPlanningsRefAndCustomerId < ActiveRecord::Migration[6.1]
  INDEX_NAME = 'index_plannings_on_customer_id_and_lower_ref'

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
    say_with_time 'Clearing duplicate planning refs per customer (case insensitive)' do
      execute <<~SQL.squish
        UPDATE plannings
        SET ref = NULL,
            updated_at = NOW()
        WHERE id IN (
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
        )
      SQL
    end
  end
end
