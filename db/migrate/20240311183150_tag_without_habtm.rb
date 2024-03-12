class TagWithoutHabtm < ActiveRecord::Migration
  def change
    rename_table :destinations_tags, :tag_destinations
    rename_table :tags_visits, :tag_visits
    rename_table :plannings_tags, :tag_plannings

    add_timestamps :tag_destinations, default: Time.zone.now
    add_timestamps :tag_plannings, default: Time.zone.now
    add_timestamps :tag_visits, default: Time.zone.now
  end
end
