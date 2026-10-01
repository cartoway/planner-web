# frozen_string_literal: true

class AddEmailToDestinations < ActiveRecord::Migration[6.1]
  def change
    add_column :destinations, :email, :string unless column_exists?(:destinations, :email)
  end
end
