# frozen_string_literal: true

# Append-only archive table (no primary key). Used for insert_all from operations.
class HistoryStop < ApplicationRecord
  self.table_name = 'history_stops'
  self.primary_key = nil
end
