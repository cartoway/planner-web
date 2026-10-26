# frozen_string_literal: true

class AddSpacesToRoles < ActiveRecord::Migration[6.1]
  def up
    add_column :roles, :spaces, :jsonb, null: false, default: {}

    say_with_time 'migrate Role.forms → Role.spaces' do
      Role.reset_column_information
      Role.find_each do |role|
        forms = role.forms.is_a?(Hash) ? role.forms : {}
        role.update_columns(
          spaces: spaces_from_legacy_forms(forms),
          updated_at: Time.current
        )
      end
    end

    rename_column :roles, :operations, :planning_toolbar
    remove_column :roles, :forms
  end

  def down
    add_column :roles, :forms, :jsonb, null: false, default: {}
    rename_column :roles, :planning_toolbar, :operations
    remove_column :roles, :spaces
  end

  private

  # One-shot only: compact legacy forms { visible, usable } → normalized spaces.
  def spaces_from_legacy_forms(forms_hash)
    str = forms_hash.is_a?(Hash) ? forms_hash.stringify_keys : {}
    out = {}
    Preferences::Catalog::SPACE_KEYS.each do |key|
      next unless Preferences::Catalog::SPACE_ACTIONS.fetch(key).include?('edit')

      e = str[key].is_a?(Hash) ? str[key].stringify_keys : {}
      visible = Preferences::Catalog.truthy?(e.fetch('visible', Preferences::Catalog::Spaces::NORMALIZE_SPACE_VISIBLE_DEFAULT))
      usable = Preferences::Catalog.truthy?(e.fetch('usable', Preferences::Catalog::Spaces::NORMALIZE_SPACE_USABLE_DEFAULT))
      out[key] = Preferences::Catalog::Spaces.default_space_entry(
        key, visible: visible, usable: usable && visible, actions_all_usable: usable && visible
      )
    end
    # Existing roles: keep Operations fully open so device-enabled customers are not locked out.
    out['operations'] = Preferences::Catalog::Spaces.default_space_entry(
      'operations', visible: true, usable: true, actions_all_usable: true
    )
    Preferences::Catalog.normalize_spaces(out)
  end
end
