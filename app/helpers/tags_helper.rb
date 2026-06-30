# Copyright © Mapotempo, 2016
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
module TagsHelper
  def tag_icon(tag)
    content_tag :i, '',
                class: 'fa fa-lg %s' % [tag.default_icon],
                style: 'color: %s' % [tag.default_color]
  end

  # True when the tag has a customer-defined color and/or icon (not inherited defaults).
  def tag_list_badge_customized?(tag)
    tag.color.present? || tag.icon.present?
  end

  def tag_list_badge_icon_class(tag)
    tag.icon.presence || tag.default_icon
  end

  def tag_list_badge_icon_style(tag)
    "color: #{tag.color}" if tag.color.present?
  end
end
