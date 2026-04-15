require 'test_helper'

class UserTest < ActiveSupport::TestCase

  def user_hash(customer, locale)
    { locale: locale, customer: customer, email: 'julien@example.com', password: 'dummy_password' }
  end

  test 'should not save' do
    user = User.new
    assert_not user.save, 'Saved without required fields'
  end

  test 'should destroy' do
    user = users(:user_one)
    user.destroy
  end

  test 'should create with locale' do
    user = User.create(user_hash(customers(:customer_one), 'fr'))
    assert user.valid?
  end

  test 'toolbar segment visibility follows role operations when role_id is set' do
    return unless Role.column_names.include?('operations')

    reseller = resellers(:reseller_one)
    ops = Preferences::Catalog.default_operations.deep_dup
    ops['planning']['segment_controls']['optimize'] = {
      'visible' => false, 'usable' => false
    }
    role = Role.create!(
      reseller: reseller,
      name: 'Restricted toolbar',
      operations: ops,
      forms: Preferences::Catalog.default_forms
    )
    user = users(:user_one)
    user.update!(role_id: role.id)

    assert user.operation_segment_visible?(:planning, 'zoning')
    assert_not user.operation_segment_visible?(:planning, 'optimize')
  end

  test 'should reset device attributes on duplication' do
    u = users(:user_one)
    customer_dopple = Customer.for_duplication.find(u.customer.id).duplicate
    current_user = customer_dopple.users.find { |user| u.ref == user.ref }

    # Devise attributes must has been nilified on duplication
    %i[confirmed_at confirmation_sent_at reset_password_token].each { |attr|
      assert_not current_user.send(attr)
    }

    assert current_user.confirmation_token
  end
end
