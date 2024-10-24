class RenameIconNameToTags < ActiveRecord::Migration
  def up
    Tag.transaction do
      Tag.find_in_batches do |tags|
        tags.each do |tag|
          if tag.icon == 'square'
            tag.icon = 'fa-square'
          elsif tag.icon == 'star'
            tag.icon = 'fa-star'
          elsif tag.icon == 'diamon'
            tag.icon = 'fa-play'
          elsif tag.icon == 'user'
            tag.icon = 'fa-user'
          end
          tag.migration_skip = true
          tag.save!(validate: false)
        end
      end
    end
  end

  def down
    Tag.transaction do
      Tag.find_in_batches do |tags|
        tags.each do |tag|
          if tag.icon == 'fa-square'
            tag.icon = 'square'
          elsif tag.icon == 'fa-star'
            tag.icon = 'star'
          elsif tag.icon == 'fa-play'
            tag.icon = 'diamond'
          elsif tag.icon == 'fa-user'
            tag.icon = 'user'
          else
            tag.icon = nil
          end
          tag.migration_skip = true
          tag.save!(validate: false)
        end
      end
    end
  end
end
