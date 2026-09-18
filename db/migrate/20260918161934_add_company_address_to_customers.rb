# frozen_string_literal: true

class AddCompanyAddressToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :company_name, :string
    add_column :customers, :company_street, :string
    add_column :customers, :company_postalcode, :string
    add_column :customers, :company_city, :string
    add_column :customers, :company_detail, :string
    add_column :customers, :company_phone, :string
  end
end
