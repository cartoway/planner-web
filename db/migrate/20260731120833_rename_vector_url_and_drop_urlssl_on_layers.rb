# frozen_string_literal: true

class RenameVectorUrlAndDropUrlsslOnLayers < ActiveRecord::Migration[6.1]
  def up
    if column_exists?(:layers, :vector_url) && !column_exists?(:layers, :vector_style_url)
      rename_column :layers, :vector_url, :vector_style_url
    elsif !column_exists?(:layers, :vector_style_url)
      add_column :layers, :vector_style_url, :string
    end

    return unless column_exists?(:layers, :urlssl)

    # Prefer the SSL tile URL as the single source of truth (hosts may differ from http url).
    execute <<~SQL.squish
      UPDATE layers
      SET url = urlssl
      WHERE urlssl IS NOT NULL AND urlssl <> ''
    SQL
    remove_column :layers, :urlssl
  end

  def down
    unless column_exists?(:layers, :urlssl)
      add_column :layers, :urlssl, :string
      execute <<~SQL.squish
        UPDATE layers SET urlssl = url WHERE url IS NOT NULL AND url <> ''
      SQL
      change_column_null :layers, :urlssl, false
    end

    if column_exists?(:layers, :vector_style_url) && !column_exists?(:layers, :vector_url)
      rename_column :layers, :vector_style_url, :vector_url
    end
  end
end
