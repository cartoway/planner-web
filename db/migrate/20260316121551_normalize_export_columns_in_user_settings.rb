class NormalizeExportColumnsInUserSettings < ActiveRecord::Migration[6.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = 'users'
  end

  LEGACY_TO_CANONICAL = {
    'ref_planning' => 'planning_ref',
    'planning' => 'planning_name',
    'vehicle' => 'ref_vehicle',
    'tags_visit' => 'tag_visits'
  }.freeze

  CANONICAL_TO_LEGACY = {
    'planning_ref' => 'ref_planning',
    'planning_name' => 'planning',
    'ref_vehicle' => 'vehicle',
    'tag_visits' => 'tags_visit'
  }.freeze

  def up
    rewrite_export_settings_columns!(LEGACY_TO_CANONICAL)
  end

  def down
    rewrite_export_settings_columns!(CANONICAL_TO_LEGACY)
  end

  private

  def rewrite_export_settings_columns!(mapping)
    MigrationUser.find_each do |user|
      settings = user.export_settings
      next unless settings.is_a?(Hash)

      export_columns = settings['export']
      skips_columns = settings['skips']

      rewritten_export =
        if export_columns.is_a?(Array)
          export_columns.map { |column| mapping.fetch(column.to_s, column.to_s) }
        else
          export_columns
        end

      rewritten_skips =
        if skips_columns.is_a?(Array)
          skips_columns.map { |column| mapping.fetch(column.to_s, column.to_s) }
        else
          skips_columns
        end

      next if rewritten_export == export_columns && rewritten_skips == skips_columns

      user.update_columns(
        export_settings: settings.merge('export' => rewritten_export, 'skips' => rewritten_skips)
      )
    end
  end
end
