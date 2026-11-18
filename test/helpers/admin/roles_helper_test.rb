# frozen_string_literal: true

require 'test_helper'

class Admin::RolesHelperTest < ActionView::TestCase
  test 'role_transfer_items builds value label hashes' do
    items = role_transfer_items(%w[a b]) { |id| id.upcase }

    assert_equal [{ value: 'a', label: 'A' }, { value: 'b', label: 'B' }], items
  end

  test 'role_operations_mobile_capability_label translates dotted capability keys' do
    I18n.with_locale(:en) do
      assert_equal 'Submit proofs', role_operations_mobile_capability_label('stops.proofs')
      OperationsMobile::CAPABILITIES.each do |key|
        label = role_operations_mobile_capability_label(key)
        refute_equal key.tr('.', ' ').humanize, label, "missing en translation for #{key}"
      end
    end
    I18n.with_locale(:fr) do
      assert_equal 'Transmettre des preuves', role_operations_mobile_capability_label('stops.proofs')
    end
  end
end
