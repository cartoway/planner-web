# frozen_string_literal: true

class AddDemoJobToOperations < ActiveRecord::Migration[6.1]
  def change
    add_column :operations, :demo_job_id, :integer
    add_index :operations, :demo_job_id, name: 'index_operations_on_demo_job_id'
  end
end
