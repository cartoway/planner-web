# frozen_string_literal: true

require 'test_helper'

class RoleTest < ActiveSupport::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    @role = Role.create!(
      reseller: @reseller,
      name: "Role destroy test #{SecureRandom.hex(4)}"
    )
  end

  test 'can destroy reseller default role and nullifies reseller default_role_id' do
    @reseller.update_column(:default_role_id, @role.id)

    assert_difference('Role.count', -1) do
      assert @role.destroy
    end

    assert_nil @reseller.reload.default_role_id
  end

  test 'can destroy role with assigned users and nullifies role_id' do
    user = users(:user_one)
    user.update_column(:role_id, @role.id)

    assert_difference('Role.count', -1) do
      assert @role.destroy
    end

    assert_nil user.reload.role_id
  end
end
