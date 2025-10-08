# Copyright © Mapotempo, 2015
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
class ParseIdsRefs
  def self.read(raw_id)
    if !raw_id.is_a?(Integer) && raw_id.start_with?('ref:')
      {ref: raw_id[4..-1]}
    else
      {id: Integer(raw_id)}
    end
  end

  def self.match(raw_id, obj)
    o = read(raw_id)
    o[:id] == obj.id || (o.key?(:ref) && o[:ref] == obj.ref&.downcase)
  end

  def self.match_ref?(raw_ref, obj)
    raw_ref.to_s.downcase == obj.ref&.downcase
  end

  def self.where(clazz, param)
    ids = Hash[param.collect{ |id|
      read(id)
    }.group_by{ |e|
      e.keys[0]
    }.collect{ |k, v|
      [k, v.collect{ |vv| vv[k] }]
    }]
    table = clazz.arel_table
    table[:id].in(ids[:id]).or(table[:ref].in(ids[:ref]))
  end
end
