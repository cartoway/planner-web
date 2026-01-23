class AddDichoMinimumServiceSizeToCustomer < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :optimization_dicho_minimum_service_size, :integer, default: nil
  end
end
