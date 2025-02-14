# Copyright © Mapotempo, 2014-2015
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
class V01::Entities::Tag < Grape::Entity
  def self.entity_name
    'V01_Tag'
  end

  expose(:id, documentation: { type: Integer })
  expose(:label, documentation: { type: String })
  expose(:ref, documentation: { type: String })
  expose(:color, documentation: { type: String, desc: "Color code with #. Default: #{Planner::Application.config.tag_color_default}." })
  expose(:icon, documentation: { type: String, desc: "Icon name from font-awesome. Default: #{Planner::Application.config.tag_icon_default}." })
  expose(:icon_size, documentation: { type: String, values: ::Tag::ICON_SIZE, desc: "Icon size. Default: #{Planner::Application.config.tag_icon_size_default}." })
end
