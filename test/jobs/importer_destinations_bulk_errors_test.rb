# frozen_string_literal: true

require 'test_helper'

class ImporterDestinationsBulkErrorsTest < ActiveSupport::TestCase
  setup do
    @importer = ImporterDestinations.new(customers(:customer_one))
    @importer.instance_variable_set(:@import_line_shift, 1)
  end

  test 'import_errors_with_indices uses global csv line number on second bulk slice' do
    destination = Destination.new
    destination.errors.add(:name, "can't be blank")

    message = @importer.send(
      :import_errors_with_indices,
      [[1796]],
      [[0, destination]]
    )

    assert_match(/lignes \[1798\]/, message)
    assert_no_match(/2798/, message)
  end

  test 'import_errors_with_indices reports first data row as line 2 when header present' do
    destination = Destination.new
    destination.errors.add(:name, "can't be blank")

    message = @importer.send(
      :import_errors_with_indices,
      [[0]],
      [[0, destination]]
    )

    assert_match(/lignes \[2\]/, message)
  end

  test 'import_errors_with_indices reports first row as line 1 without header shift' do
    @importer.instance_variable_set(:@import_line_shift, 0)
    destination = Destination.new
    destination.errors.add(:name, "can't be blank")

    message = @importer.send(
      :import_errors_with_indices,
      [[0]],
      [[0, destination]]
    )

    assert_match(/lignes \[1\]/, message)
  end
end
