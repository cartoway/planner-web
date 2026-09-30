# frozen_string_literal: true

class CreateVehiclePositions < ActiveRecord::Migration[6.1]
  def change
    create_table :vehicle_positions, id: :serial do |t|
      t.references :customer, type: :integer, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :vehicle, type: :integer, foreign_key: { on_delete: :nullify }, index: false
      t.references :operation, type: :integer, foreign_key: { on_delete: :cascade }, index: false
      t.references :operation_route, type: :integer, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.float :lat, null: false
      t.float :lng, null: false
      t.float :heading
      t.float :speed
      t.float :accuracy
      t.float :altitude
      t.datetime :positioned_at, null: false
      t.datetime :received_at, null: false, default: -> { 'NOW()' }
      t.string :source, null: false, default: 'mobile'
      t.jsonb :payload, null: false, default: {}
      t.datetime :created_at, null: false, default: -> { 'NOW()' }
    end

    add_index :vehicle_positions, [:vehicle_id, :positioned_at], order: { positioned_at: :desc }, name: 'index_vehicle_positions_on_vehicle_id_and_positioned_at'
    add_index :vehicle_positions, [:operation_route_id, :positioned_at], order: { positioned_at: :desc }, name: 'index_vehicle_positions_on_operation_route_id_and_positioned_at'
    add_index :vehicle_positions, [:operation_id, :positioned_at], order: { positioned_at: :desc }, name: 'index_vehicle_positions_on_operation_id_and_positioned_at'
    add_index :vehicle_positions, [:customer_id, :positioned_at], order: { positioned_at: :desc }, name: 'index_vehicle_positions_on_customer_id_and_positioned_at'
  end
end
