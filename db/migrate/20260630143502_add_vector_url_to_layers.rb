# frozen_string_literal: true

class AddVectorUrlToLayers < ActiveRecord::Migration[6.1]
  def change
    add_column :layers, :vector_url, :string
  end
end
