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
class Admin::ResellersController < ApplicationController
  load_and_authorize_resource
  before_action :set_reseller, only: [:edit, :update]

  def edit
  end

  def update
    if @reseller.update(reseller_params)
      active_service = params.dig(:reseller, :messagings, :active_service)

      messagings = @reseller.messagings || {}
      MESSAGING_SERVICES.each_key do |service_name|
        messagings[service_name] ||= {}
        messagings[service_name][:enable] = (service_name == active_service)
      end

      @reseller.update!(messagings: messagings)

      respond_to do |format|
        format.html { redirect_to edit_admin_reseller_path(@reseller), notice: t('activerecord.successful.messages.updated', model: @reseller.class.model_name.human) }
      end
    else
      respond_to do |format|
        format.html { render action: 'edit' }
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_reseller
    @reseller = Reseller.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def reseller_params
    params.require(:reseller).permit(
      :host,
      :name,
      :application_name,
      :website_url,
      :welcome_url,
      :help_url,
      :contact_url,
      :subscription_url,
      :facebook_url,
      :twitter_url,
      :linkedin_url,
      :logo_large,
      :logo_small,
      :favicon,
      :url_protocol,
      :audience_url,
      :behavior_url,
      :customer_audience_url,
      :customer_behavior_url,
      :customer_dashboard_url,
      :external_callback_url,
      :external_callback_url_name,
      :enable_external_callback,
      messagings: {
        vonage: [:api_key, :api_secret],
        sms_partner: [:api_key]
      }
    )
  end
end
