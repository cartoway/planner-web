# frozen_string_literal: true

class AddLastAsyncJobsToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :last_async_jobs, :jsonb, default: {}, null: false
  end
end
