# Copyright © Mapotempo, 2014-2016
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
class V01::Entities::Order < Grape::Entity
  def self.entity_name
    'V01_Order'
  end

  expose(:id, documentation: { type: Integer })
  expose(:visit_id, documentation: { type: Integer })
  # Deprecated
  expose(:destination_id, documentation: { hidden: true, deprecated: true, type: Integer, desc: 'Deprecated, use visit_id.' }) { |m| m.visit.destination.id }
  expose(:shift, documentation: { type: Integer })
  expose(:product_ids, documentation: { type: Integer, is_array: true })
end
