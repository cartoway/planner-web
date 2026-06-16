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

  test 'generate_temporary_password meets devise length and is unpredictable' do
    passwords = 10.times.map { User.generate_temporary_password }

    assert passwords.all? { |password| password.length.between?(8, 128) }
    assert_equal passwords.uniq.size, passwords.size
    refute passwords.any? { |password| password.match?(/\A\d+\z/) }
  end

  test 'does not assign reseller default role on create' do
    return unless Role.column_names.include?('operations')

    reseller = resellers(:reseller_one)
    role = Role.create!(
      reseller: reseller,
      name: 'Model default role',
      ref: "model_default_#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.baseline_role_operations_json,
      forms: Preferences::Catalog.baseline_role_forms_json
    )
    reseller.update_column(:default_role_id, role.id)

    user = User.create!(
      user_hash(customers(:customer_one), 'fr').merge(email: 'no-api-default-role@example.com')
    )
    assert_nil user.role_id
  ensure
    reseller&.update_column(:default_role_id, nil)
    role&.destroy
  end

  test 'does not assign role on create when reseller has no default role' do
    user = User.create!(
      user_hash(customers(:customer_one), 'fr').merge(email: 'no-default-role@example.com')
    )
    assert_nil user.role_id
  end

  test 'after_create sends password email when send_email toggle is on' do
    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      User.create!(user_hash(customers(:customer_one), 'fr').merge(send_email: '1'))
    end
  end

  test 'after_create does not send password email when send_email toggle is off' do
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      User.create!(user_hash(customers(:customer_one), 'fr').merge(send_email: '0'))
    end
  end

  test 'after_save sends connection email when user confirms for the first time' do
    user = users(:user_one)
    user.update_columns(confirmed_at: nil, confirmation_sent_at: 1.day.ago)
    user.reload

    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      user.update!(confirmed_at: Time.zone.now)
    end
  end

  test 'after_save does not send connection email when user was already confirmed' do
    user = users(:user_one)
    assert user.confirmed_at.present?

    assert_no_difference('ActionMailer::Base.deliveries.size') do
      user.update!(time_zone: 'Hawaii')
    end
  end

  test 'after_save sends connection email when confirmation_sent_at is nil and user is still unconfirmed' do
    user = User.create!(
      user_hash(customers(:customer_one), 'fr').merge(
        email: 'unconfirmed-no-confirmation-sent@example.com',
        send_email: '0',
        confirmed_at: nil
      )
    )
    user.update_column(:confirmation_sent_at, nil)

    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      user.update!(time_zone: 'Paris')
    end
  end

  test 'after_save does not send connection email when password email was sent but user still unconfirmed' do
    user = User.create!(
      user_hash(customers(:customer_one), 'fr').merge(
        email: 'unconfirmed-with-confirmation-sent@example.com',
        send_email: '0',
        confirmed_at: nil
      )
    )
    user.update_column(:confirmation_sent_at, 1.day.ago)

    assert_no_difference('ActionMailer::Base.deliveries.size') do
      user.update!(time_zone: 'London')
    end
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
