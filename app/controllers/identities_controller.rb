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
class IdentitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_identity

  def destroy
    if @identity.user == current_user
      @identity.destroy
      redirect_to edit_user_path(current_user), notice: t('identities.destroy.success', provider: t('all.providers.' + @identity.provider))
    else
      redirect_to edit_user_path(current_user), alert: t('identities.destroy.unauthorized', provider: t('all.providers.' + @identity.provider))
    end
  end

  private

  def set_identity
    @identity = Identity.find(params[:id])
  end
end
