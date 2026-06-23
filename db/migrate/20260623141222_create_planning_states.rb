# frozen_string_literal: true

class CreatePlanningStates < ActiveRecord::Migration[6.1]
  NEW_OPERATION_IDS = %w[planning_states duplicate planning_dashboard].freeze

  PLANNING_TOOLBAR_OPERATION_IDS = %w[
    external_callback optimize zoning vehicle_usage_set toggle_routes toggle_route_data
    lock_routes activate_stops export refresh
  ].freeze

  def up
    create_table :planning_states do |t|
      t.references :planning, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :captured_at, null: false
      t.string :trigger, null: false
      t.string :category, null: false
      t.boolean :pinned, null: false, default: false
      t.jsonb :payload, null: false, default: {}
      t.jsonb :statistics, null: false, default: {}

      t.timestamps
    end

    add_index :planning_states, [:planning_id, :captured_at]
    add_index :planning_states, [:planning_id, :category, :captured_at],
              name: 'index_planning_states_on_planning_id_category_captured_at'
    add_index :planning_states, [:planning_id, :category, :pinned],
              name: 'index_planning_states_on_planning_id_category_pinned'

    enable_planning_operations_for_roles!
  end

  def down
    disable_planning_operations_for_roles!
    drop_table :planning_states
  end

  private

  def enable_planning_operations_for_roles!
    Role.reset_column_information
    Role.find_each do |role|
      next unless role.operations.is_a?(Hash)

      ops = role.operations.deep_dup.deep_stringify_keys
      planning = (ops['planning'] || {}).deep_dup
      controls = (planning['segment_controls'] || {}).stringify_keys
      segments = Array(planning['segments']).map(&:to_s)
      usable = full_planning_toolbar?(controls)

      NEW_OPERATION_IDS.each do |operation_id|
        controls[operation_id] = { 'visible' => true, 'usable' => usable }
        segments << operation_id unless segments.include?(operation_id)
      end

      planning['segments'] = segments
      planning['segment_controls'] = controls
      ops['planning'] = planning

      role.update_columns(operations: Preferences::Catalog.normalize_operations(ops))
    end
  end

  def disable_planning_operations_for_roles!
    Role.reset_column_information
    Role.find_each do |role|
      next unless role.operations.is_a?(Hash)

      ops = role.operations.deep_dup.deep_stringify_keys
      planning = ops['planning']
      next unless planning.is_a?(Hash)

      planning = planning.deep_dup
      planning['segments'] = Array(planning['segments']).map(&:to_s) - NEW_OPERATION_IDS
      controls = (planning['segment_controls'] || {}).stringify_keys
      NEW_OPERATION_IDS.each { |operation_id| controls.delete(operation_id) }
      planning['segment_controls'] = controls
      ops['planning'] = planning

      role.update_columns(operations: Preferences::Catalog.normalize_operations(ops))
    end
  end

  def full_planning_toolbar?(controls)
    PLANNING_TOOLBAR_OPERATION_IDS.all? do |operation_id|
      segment = controls[operation_id]
      segment.is_a?(Hash) &&
        Preferences::Catalog::Core.truthy?(segment['visible']) &&
        Preferences::Catalog::Core.truthy?(segment['usable'])
    end
  end
end
