class AddAuthorizeOvertakeToCustomer < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :authorize_overtake, :bool, default: false
  end
end
