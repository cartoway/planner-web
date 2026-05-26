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
      concat '<span style="color: red; font-weight: bold;">'.html_safe if Rails.configuration.max_plannings_default && Rails.configuration.max_plannings_default <= customer.plannings_count
      concat customer.plannings_count
      concat '</span>'.html_safe if Rails.configuration.max_plannings_default && Rails.configuration.max_plannings_default <= customer.plannings_count
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

  def customer_router_grouped_options(customer, admin:)
    if admin
      profile_router_grouped_options_for_admin(customer)
    else
      router_grouped_options_for_customer(Router.all)
    end
  end

  def customer_router_selected_value(customer, admin:)
    return nil if customer.router_id.blank?

    if admin && customer.profile_id.present?
      "#{customer.profile_id}_#{customer.router_id}_#{customer.router_dimension}"
    else
      "#{customer.router_id}_#{customer.router_dimension}"
    end
  end

  def profile_router_grouped_options_for_admin(customer)
    Profile.includes(:routers).map do |profile|
      [profile.name, profile_router_options(profile)]
    end
  end

  def router_grouped_options_for_customer(routers)
    [
      [t('activerecord.attributes.router.router_dimensions.time'), router_options_for_dimension(routers, 'time')],
      [t('activerecord.attributes.router.router_dimensions.distance'), router_options_for_dimension(routers, 'distance')]
    ]
  end

  private

  def profile_router_options(profile)
    profile.routers.flat_map do |router|
      router_options_for_router(router, profile.id)
    end
  end

  def router_options_for_dimension(routers, dimension)
    routers.select { |router| router.public_send("#{dimension}?") }.map do |router|
      [router_option_label(router, dimension), router_option_value(router, dimension)]
    end
  end

  def router_options_for_router(router, profile_id)
    options = []
    if router.time?
      options << [router_option_label(router, 'time'), router_option_value(router, 'time', profile_id)]
    end
    if router.distance?
      options << [router_option_label(router, 'distance'), router_option_value(router, 'distance', profile_id)]
    end
    options
  end

  def router_option_label(router, dimension)
    router.translated_name + ' - ' + t("activerecord.attributes.router.router_dimensions.#{dimension}")
  end

  def router_option_value(router, dimension, profile_id = nil)
    if profile_id
      "#{profile_id}_#{router.id}_#{dimension}"
    else
      "#{router.id}_#{dimension}"
    end
  end

end
