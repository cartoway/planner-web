# frozen_string_literal: true

require 'test_helper'

class ResellerTest < ActiveSupport::TestCase
  setup do
    @reseller = resellers(:reseller_one)
  end

  test 'creates default permissions role on create' do
    host = "reseller-test-#{SecureRandom.hex(6)}.example.test"
    reseller = Reseller.new(host: host, name: 'New reseller for role test')
    assert_difference('Role.count', 1) do
      reseller.save!
    end

    role = reseller.roles.first!
    assert_equal Role.default_permissions_role_ref, role.ref
    assert_equal role.id, reseller.reload.default_role_id
    assert_equal I18n.t('admin.roles.default_permissions_role_name'), role.name
    assert_equal Role.default_new_reseller_role_icon, role.icon
    assert_equal(
      Preferences::Catalog.baseline_role_operations_json,
      role.operations
    )
    assert_equal(
      Preferences::Catalog.baseline_role_forms_json,
      role.forms
    )
    assert_difference('Role.count', -1) do
      reseller.destroy!
    end
  end

  test 'create_default_permissions_role_for! is idempotent' do
    host = "reseller-idem-#{SecureRandom.hex(6)}.example.test"
    reseller = Reseller.new(host: host, name: 'Idempotent role test')
    assert_difference('Role.count', 1) do
      reseller.save!
    end

    assert_no_difference('Role.count') do
      Role.create_default_permissions_role_for!(reseller)
    end

    assert_difference('Role.count', -1) do
      reseller.destroy!
    end
  end

  test 'allows several roles with no ref for the same reseller' do
    reseller = @reseller
    ops = Preferences::Catalog.normalize_operations({})
    forms = Preferences::Catalog.normalize_forms({})
    Role.create!(
      reseller: reseller,
      name: "Sans ref A #{SecureRandom.hex(4)}",
      ref: nil,
      operations: ops,
      forms: forms
    )
    role_b = Role.create!(
      reseller: reseller,
      name: "Sans ref B #{SecureRandom.hex(4)}",
      ref: '',
      operations: ops,
      forms: forms
    )
    assert_nil role_b.ref
    assert role_b.persisted?
  end

  test 'can add a second role using no_role catalog seeds (same pattern as db/seeds.rb)' do
    host = "reseller-seed-role-#{SecureRandom.hex(6)}.example.test"
    reseller = Reseller.create!(host: host, name: 'Extra role reseller')

    assert_equal 1, reseller.roles.count

    Role.create!(
      reseller: reseller,
      name: 'Secondary seed role',
      ref: "seed_extra_#{SecureRandom.hex(4)}",
      operations: Preferences::Catalog.normalize_operations(Preferences::Catalog.no_role_operations_seed_hash),
      forms: Preferences::Catalog.normalize_forms(Preferences::Catalog.no_role_forms_seed_hash)
    )

    assert_equal 2, reseller.roles.count
  end

  test 'should call invalidate cache after update' do
    ResellerCacheService.expects(:invalidate).once.with(@reseller.host)
    @reseller.update!(name: 'New Name')
  end
end
