class AddPostGisExtension < ActiveRecord::Migration[6.1]
  def up
    enable_extension 'postgis'
  end

  def down
    disable_extension 'postgis'
  end
end
