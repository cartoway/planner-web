# Copyright © Mapotempo, 2017
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  before_save :set_creation_date

  def set_creation_date
    # Align precision of second to Postgres default. Avoid object change when reload from database.
    self.updated_at ||= DateTime.now.iso8601(6)
    self.created_at ||= self.updated_at
  end

  MAX_RETRIES = 3

  def self.import_transaction(obj, **options)
    retries = 0
    begin
      ActiveRecord::Base.transaction(requires_new: true) do
        self.import(obj, **options)
      end
    rescue ActiveRecord::SerializationFailure => e
      retries += 1
      if retries <= MAX_RETRIES
        retry
      else
        raise e
      end
    end
  end
end
