# Copyright © Mapotempo, 2013-2014
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
class IndexController < ApplicationController
  include IndexHelper
  before_action :customer_payment_period_month, if: :current_user

  def index
    @customer = current_user && current_user.customer
    @customer_summary = customer_summary
  end

  def unsupported_browser
    render layout: '_unsupported_browser'
  end

  def customer_payment_period_month
    if current_user.customer
      customer = current_user.customer
      if customer.end_subscription && customer.end_subscription >= Time.now
        if !customer.test && (customer.end_subscription - 30.days) <= Time.now
          flash.now[:warning] = I18n.t('all.subscribe.expiration_date', date: I18n.l((customer.end_subscription - 1.second), format: :long), reseller: @reseller&.name)
        elsif (customer.end_subscription - 3.days) <= Time.now
          flash.now[:warning] = I18n.t('all.subscribe.expiration_date_test', date: I18n.l((customer.end_subscription - 1.second), format: :long))
        end
      end
    end
  end
end
