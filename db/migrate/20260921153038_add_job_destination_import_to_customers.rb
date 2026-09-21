# frozen_string_literal: true

class AddJobDestinationImportToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :job_destination_import_id, :integer
    add_index :customers, :job_destination_import_id, name: 'index_customers_on_job_destination_import_id'
  end
end
