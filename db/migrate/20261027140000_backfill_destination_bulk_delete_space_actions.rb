# frozen_string_literal: true

# Seed new space actions on existing roles:
# - destination.delete_all_destinations ← destination.edit
# - destination.delete_all_visits ← hidden
# - tags.delete_visits_by_tags ← tags.edit
# - tags.delete_destinations_by_tags ← tags.edit
class BackfillDestinationBulkDeleteSpaceActions < ActiveRecord::Migration[6.1]
  def up
    Role.find_each do |role|
      spaces = Preferences::Catalog.normalize_spaces(role.spaces)

      if (edit = spaces.dig('destination', 'actions', 'segment_controls', 'edit'))
        controls = spaces['destination']['actions']['segment_controls']
        controls['delete_all_destinations'] = edit.deep_dup
        controls['delete_all_visits'] = { 'visible' => false, 'usable' => false }
      end

      if (edit = spaces.dig('tags', 'actions', 'segment_controls', 'edit'))
        controls = spaces['tags']['actions']['segment_controls']
        controls['delete_visits_by_tags'] = edit.deep_dup
        controls['delete_destinations_by_tags'] = edit.deep_dup
      end

      role.update_columns(spaces: spaces, updated_at: Time.current)
    end
  end

  def down
    Role.find_each do |role|
      spaces = Preferences::Catalog.normalize_spaces(role.spaces)
      spaces.dig('destination', 'actions', 'segment_controls')&.except!('delete_all_destinations', 'delete_all_visits')
      spaces.dig('tags', 'actions', 'segment_controls')&.except!('delete_visits_by_tags', 'delete_destinations_by_tags')
      role.update_columns(spaces: spaces, updated_at: Time.current)
    end
  end
end
