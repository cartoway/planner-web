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
module CustomersHelper
  def customer_plannings_count(customer)
    capture do
      concat '<span style="color: red; font-weight: bold;">'.html_safe if Rails.configuration.max_plannings_default && Rails.configuration.max_plannings_default <= customer.plannings.count
      concat customer.plannings.count
      concat '</span>'.html_safe if Rails.configuration.max_plannings_default && Rails.configuration.max_plannings_default <= customer.plannings.count
    end
  end

  def has_vehicle_with_unauthorized_router(customer)
    return false if customer.new_record? || customer.profile.blank? || customer.vehicles.where.not(router_id: nil).empty?
    (customer.vehicles.pluck(:router_id) - customer.profile.routers.pluck(:id)).present?
  end

  def has_user_with_unauthorized_layer(customer)
    return false if customer.new_record? || customer.profile.blank?
    (customer.users.pluck(:layer_id) - customer.profile.layers.pluck(:id)).present?
  end

  def customer_external_callback_name(customer, default)
    trad = customer.reseller[:external_callback_url_name] ? customer.reseller[:external_callback_url_name] : default
    t('web.form.default', n: trad)
  end

  def customer_external_callback_url(customer)
    customer.reseller[:external_callback_url] ? t('web.form.default', n: customer.reseller[:external_callback_url]) : ''
  end

  def deliverable_unit_icons(customer)
    customer.deliverable_units.map{ |du|
      [du.id, du.default_icon]
    }.to_h
  end

end
