# frozen_string_literal: true

# Copyright © Cartoway, 2024
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

class Admin::ToolsController < ApplicationController
  include V2Layout

  # Render third-party admin tools inside the main application layout via iframe.

  def performance
    render_tools_page('admin/tools/performance')
  end

  def delayed_job
    render_tools_page('admin/tools/delayed_job')
  end

  private

  def render_tools_page(template)
    if layout_v2?
      render_page template
    else
      render template
    end
  end
end
