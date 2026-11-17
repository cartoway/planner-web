# frozen_string_literal: true

# Copyright © Cartoway
require 'test_helper'

class ResellerScopesTest < ActiveSupport::TestCase
  test 'Account.for_reseller_customers excludes admin-only accounts and search matches name' do
    reseller = resellers(:reseller_one)
    customer = customers(:customer_one)
    scoped = Account.for_reseller_customers(reseller.id)

    customer_account_ids = User.unscope(:order).where(customer_id: customer.id).distinct.pluck(:account_id)
    assert customer_account_ids.any?
    assert_equal customer_account_ids.sort, (scoped.pluck(:id) & customer_account_ids).sort

    admin_only = User.unscope(:order).where(reseller_id: reseller.id, customer_id: nil).pluck(:account_id)
    assert_empty scoped.where(id: admin_only).pluck(:id)

    named = Account.for_reseller_customers(reseller.id).where(id: customer_account_ids).first
    named.update_columns(name: 'Scope Search Target')
    assert_includes Account.for_reseller_customers(reseller.id).search('Scope Search').pluck(:id), named.id
  end

  test 'Customer.for_reseller_id and search_by_name_or_ref' do
    reseller = resellers(:reseller_one)
    customer = customers(:customer_one)

    assert_includes Customer.for_reseller_id(reseller.id).pluck(:id), customer.id
    assert_includes Customer.for_reseller_id(reseller.id).search_by_name_or_ref(customer.name).pluck(:id), customer.id
  end

  test 'User.for_reseller includes admin and customer memberships; status scopes filter' do
    reseller = resellers(:reseller_one)
    admin = users(:user_admin)
    member = users(:user_one)

    ids = User.for_reseller(reseller.id).pluck(:id)
    assert_includes ids, admin.id
    assert_includes ids, member.id

    assert_includes User.active.pluck(:id), member.id if member.status == 'active'
    assert User.with_open_status.where(id: member.id).exists?
  end
end
