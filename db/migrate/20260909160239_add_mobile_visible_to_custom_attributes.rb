class AddMobileVisibleToCustomAttributes < ActiveRecord::Migration[6.1]
  # Matches CustomAttribute.object_class enum values for visit, vehicle and route.
  MOBILE_ELIGIBLE_OBJECT_CLASSES = [0, 1, 4].freeze

  def up
    return if column_exists?(:custom_attributes, :mobile_visible)

    add_column :custom_attributes, :mobile_visible, :boolean, null: false, default: true
    execute <<~SQL.squish
      UPDATE custom_attributes
      SET mobile_visible = false
      WHERE object_class IN (#{MOBILE_ELIGIBLE_OBJECT_CLASSES.join(', ')})
    SQL
  end

  def down
    return unless column_exists?(:custom_attributes, :mobile_visible)

    remove_column :custom_attributes, :mobile_visible
  end
end
