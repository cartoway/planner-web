require 'test_helper'

class ImportJsonTest < ActiveSupport::TestCase
  setup do
    @importer = ImporterDestinations.new(customers(:customer_one))
  end

  test 'should upload' do
    import_csv = ImportJson.new(importer: @importer, replace: false, json: [{name: 'plop'}])
    assert import_csv.valid?
  end

  test 'should not import too many destinations' do
    importer_destinations = ImporterDestinations.new(customers(:customer_one))
    def importer_destinations.max_lines
      2
    end

    assert_difference('Destination.count', 0) do
      assert !ImportJson.new(importer: importer_destinations, replace: false, json: [{name: 'plop'}] * 5).import
    end
  end
end
