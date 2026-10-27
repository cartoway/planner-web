# frozen_string_literal: true

class EnableLayoutV2ByDefault < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL.squish
      UPDATE users
      SET headers = jsonb_set(COALESCE(headers, '{}'::jsonb), '{destinations_index,version}', '"v2"', true)
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE users
      SET headers = jsonb_set(COALESCE(headers, '{}'::jsonb), '{destinations_index,version}', '"legacy"', true)
    SQL
  end
end
