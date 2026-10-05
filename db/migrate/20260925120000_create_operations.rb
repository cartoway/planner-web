# frozen_string_literal: true

class CreateOperations < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :operations_mobile, :boolean, null: false, default: false

    create_table :operations, id: :serial do |t|
      t.references :customer, type: :integer, null: false, foreign_key: { on_delete: :cascade }, index: { name: 'index_operations_on_customer_id' }
      t.references :planning, type: :integer, foreign_key: { on_delete: :nullify }, index: false
      t.date :date, null: false
      t.string :name, limit: 255, null: false
      t.string :ref
      t.string :status, null: false, default: 'in_progress'
      t.datetime :published_at, null: false, default: -> { 'NOW()' }
      t.datetime :synced_at
      t.string :structure_fingerprint
      t.datetime :closed_at
      t.datetime :cancelled_at
      t.jsonb :planning_snapshot, null: false, default: {}
      t.jsonb :deliverable_units_snapshot, null: false, default: []
      t.jsonb :custom_attributes, null: false, default: {}
      t.timestamps null: false
    end

    add_index :operations, [:customer_id, :date], name: 'index_operations_on_customer_id_and_date'
    add_index :operations, :planning_id, name: 'index_operations_on_planning_id'
    add_index :operations, :status, name: 'index_operations_on_status'
    execute <<~SQL
      CREATE UNIQUE INDEX index_operations_on_customer_id_lower_ref_date
        ON public.operations (customer_id, lower((ref)::text), date)
        WHERE ref IS NOT NULL;
    SQL

    create_table :operation_routes, id: :serial do |t|
      t.references :operation, type: :integer, null: false, foreign_key: { on_delete: :cascade }, index: { name: 'index_operation_routes_on_operation_id' }
      t.references :route, type: :integer, foreign_key: { on_delete: :nullify }, index: { name: 'index_operation_routes_on_route_id' }
      t.references :vehicle_usage, type: :integer, foreign_key: { on_delete: :nullify }, index: false
      t.references :vehicle, type: :integer, foreign_key: { on_delete: :nullify }, index: { name: 'index_operation_routes_on_vehicle_id' }
      t.integer :index
      t.string :ref, limit: 255
      t.string :color
      t.boolean :hidden, null: false, default: false
      t.boolean :unassigned, null: false, default: false
      t.string :sync_state, null: false, default: 'active'
      t.jsonb :vehicle_snapshot, null: false, default: {}
      t.jsonb :vehicle_usage_snapshot, null: false, default: {}
      t.jsonb :route_snapshot, null: false, default: {}
      t.string :departure_status
      t.datetime :departure_eta
      t.datetime :departure_status_updated_at
      t.string :arrival_status
      t.datetime :arrival_eta
      t.datetime :arrival_status_updated_at
      t.datetime :last_sent_at
      t.string :last_sent_to
      t.jsonb :custom_attributes, null: false, default: {}
      t.timestamps null: false
    end

    create_table :operation_stops, id: :serial do |t|
      t.references :operation_route, type: :integer, null: false, foreign_key: { on_delete: :cascade }, index: { name: 'index_operation_stops_on_operation_route_id' }
      t.references :stop, type: :integer, foreign_key: { on_delete: :nullify }, index: false
      t.references :visit, type: :integer, foreign_key: { on_delete: :nullify }, index: { name: 'index_operation_stops_on_visit_id' }
      t.references :destination, type: :integer, foreign_key: { on_delete: :nullify }, index: { name: 'index_operation_stops_on_destination_id' }
      # store_reloads.id is bigint; an integer FK cannot reference it.
      t.references :store, type: :integer, foreign_key: { on_delete: :nullify }, index: false
      t.references :store_reload, type: :bigint, foreign_key: { on_delete: :nullify }, index: false
      t.string :kind, null: false
      t.integer :index, null: false
      t.boolean :active, null: false, default: true
      t.boolean :locked, null: false, default: false
      t.string :sync_state, null: false, default: 'active'
      t.jsonb :destination_snapshot, null: false, default: {}
      t.jsonb :visit_snapshot, null: false, default: {}
      t.jsonb :store_snapshot, null: false, default: {}
      t.jsonb :stop_snapshot, null: false, default: {}
      t.string :status
      t.datetime :eta
      t.datetime :status_updated_at
      t.jsonb :custom_attributes, null: false, default: {}
      t.jsonb :actual_quantities, null: false, default: {}
      t.timestamps null: false
    end

    add_index :operation_stops, [:operation_route_id, :index], name: 'index_operation_stops_on_operation_route_id_and_index'
    add_index :operation_stops, :status, name: 'index_operation_stops_on_status'
    add_index :operation_stops, :status_updated_at, name: 'index_operation_stops_on_status_updated_at'
    add_index :operation_stops, :stop_id, name: 'index_operation_stops_on_stop_id'
    execute <<~SQL
      ALTER TABLE operation_stops
        ADD CONSTRAINT operation_stops_kind_check CHECK (kind IN ('visit', 'rest', 'store')),
        ADD CONSTRAINT operation_stops_visit_kind_check CHECK (kind <> 'visit' OR visit_snapshot <> '{}'::jsonb);

      CREATE INDEX index_operation_stops_on_destination_snapshot_ref
        ON public.operation_stops ((destination_snapshot->>'ref'));
      CREATE INDEX index_operation_stops_on_destination_snapshot_city
        ON public.operation_stops ((destination_snapshot->>'city'));
    SQL

    create_table :operation_stop_status_events, id: :serial do |t|
      t.references :operation_stop, type: :integer, null: false, foreign_key: { on_delete: :cascade }, index: { name: 'index_operation_stop_status_events_on_stop_id' }
      t.string :status, null: false
      t.datetime :eta
      t.datetime :recorded_at, null: false
      t.string :source, null: false, default: 'mobile'
      t.string :source_ref
      t.string :actor_ref
      t.jsonb :payload, null: false, default: {}
      t.datetime :created_at, null: false, default: -> { 'NOW()' }
    end

    add_index :operation_stop_status_events, [:operation_stop_id, :recorded_at], name: 'index_operation_stop_status_events_on_stop_id_and_recorded_at'
    add_index :operation_stop_status_events, :recorded_at, name: 'index_operation_stop_status_events_on_recorded_at'
    add_index :operation_stop_status_events, :status, name: 'index_operation_stop_status_events_on_status'

    # Deleting a destination cascades to visits/stops; clear operation_stops FKs first
    # so Postgres does not fight multiple ON DELETE SET NULL on the same row.
    execute <<~SQL
      CREATE FUNCTION operation_stops_null_for_destination() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        UPDATE operation_stops
        SET destination_id = NULL,
            visit_id = NULL,
            stop_id = NULL
        WHERE destination_id = OLD.id
           OR visit_id IN (SELECT id FROM visits WHERE destination_id = OLD.id);
        RETURN OLD;
      END;
      $$;

      CREATE TRIGGER operation_stops_before_destination_delete
      BEFORE DELETE ON destinations
      FOR EACH ROW
      EXECUTE PROCEDURE operation_stops_null_for_destination();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS operation_stops_before_destination_delete ON destinations;
      DROP FUNCTION IF EXISTS operation_stops_null_for_destination();
    SQL
    drop_table :operation_delivery_trackings, if_exists: true
    drop_table :vehicle_positions, if_exists: true
    drop_table :operation_stop_status_events
    drop_table :operation_stops
    drop_table :operation_routes
    drop_table :operations
    remove_column :customers, :operations_mobile
  end
end
