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

  test 'should reset device attributes on duplication' do
    u = users(:user_one)
    customer_dopple = u.customer.duplicate
    current_user = customer_dopple.users.find { |user| u.ref == user.ref }

    # Devise attributes must has been nilified on duplication
    %i[confirmed_at confirmation_sent_at reset_password_token].each { |attr|
      assert_not current_user.send(attr)
    }

    assert current_user.confirmation_token
  end
end
