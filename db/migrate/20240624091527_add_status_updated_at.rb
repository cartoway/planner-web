class AddStatusUpdatedAt < ActiveRecord::Migration
  def change
    add_column :stops, :status_updated_at, :datetime
  end
end
