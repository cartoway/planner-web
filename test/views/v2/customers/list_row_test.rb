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

require 'test_helper'

class V2CustomersListRowTest < ActionView::TestCase
  include ApplicationHelper
  include CustomersHelper
  include Admin::UsersHelper
  include Rails.application.routes.url_helpers

  setup do
    # ActionView::TestCase has no Devise/Warden — stub before the partial calls current_user.admin?
    admin = users(:user_admin)
    view.define_singleton_method(:current_user) { admin }
    @customer = customers(:customer_one)
    @customer.description = 'Note de test'
  end

  test 'shows muted comment with Commentaire label' do
    render partial: 'v2/customers/list_row', locals: { customer: @customer }

    assert_select 'p.customer-card-comment.text-muted' do
      assert_select 'span.customer-card-comment__label', text: I18n.t('customers.index.comment_label')
      assert_select 'span.customer-card-comment__value', text: 'Note de test'
    end
  end

  test 'shows center-on-map button with customer coordinates' do
    store = @customer.stores.first
    assert store&.lat.present? && store&.lng.present?, 'fixture customer needs a positioned store'

    render partial: 'v2/customers/list_row', locals: { customer: @customer }

    assert_select ".store-row[data-customer-id=?][data-lat=?][data-lng=?]",
                  @customer.id.to_s, store.lat.to_s, store.lng.to_s
    assert_select 'button.customers-row-center:not([disabled])'
  end
end
