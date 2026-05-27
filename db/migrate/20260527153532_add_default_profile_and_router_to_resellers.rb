# frozen_string_literal: true

class AddDefaultProfileAndRouterToResellers < ActiveRecord::Migration[6.1]
  def change
    add_reference :resellers, :default_profile, foreign_key: { to_table: :profiles, on_delete: :nullify }, index: true
    add_reference :resellers, :default_router, foreign_key: { to_table: :routers, on_delete: :nullify }, index: true
  end
end
