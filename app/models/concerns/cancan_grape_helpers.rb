# frozen_string_literal: true

# Copyright © Cartoway, 2026
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
# Grape helpers aligned with grape-cancan (no gem): current_ability, authorize!, can?, cannot?
# Host API helpers must define #api_status_module (e.g. V01::Status).
module CancanGrapeHelpers
  def current_ability
    @current_ability ||= Ability.new(@current_user)
  end

  # Per-endpoint checks use authorize!(:action, Model). The global `before` calls authorize! with
  # no args (no-op here); some mounted APIs override authorize! for legacy checks (e.g. orders).
  def authorize!(*args)
    return if args.empty?

    current_ability.authorize!(*args)
  rescue CanCan::AccessDenied
    error!(api_status_module.code_response(:code_403), 403)
  end

  def can?(*args)
    current_ability.can?(*args)
  end

  def cannot?(*args)
    current_ability.cannot?(*args)
  end
end
