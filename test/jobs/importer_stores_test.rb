require 'test_helper'

class ImporterStoresTest < ActionController::TestCase
  setup do
    @customer = customers(:customer_one)
  end

  def tempfile(file, name)
    file = ActionDispatch::Http::UploadedFile.new({
      tempfile: File.new(Rails.root.join(file)),
    })
    file.original_filename = name
    file
  end

  test 'should import store' do
    assert_difference('Store.count') do
      assert ImportCsv.new(importer: ImporterStores.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_stores_one.csv', 'text.csv')).import
    end
  end

  test 'should import store with postalcode' do
    assert_difference('Store.count') do
      assert ImportCsv.new(importer: ImporterStores.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_stores_one_postalcode.csv', 'text.csv')).import
    end
  end

  test 'should import store with coord' do
    assert_difference('Store.count') do
      assert ImportCsv.new(importer: ImporterStores.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_stores_one_coord.csv', 'text.csv')).import
    end
  end

  test 'should import store two' do
    assert_difference('Store.count', 2) do
      assert ImportCsv.new(importer: ImporterStores.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_stores_two.csv', 'text.csv')).import
    end
  end

  test 'should import many-utf-8 stores' do
    assert_difference('Store.count', 5) do
      assert ImportCsv.new(importer: ImporterStores.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_stores_many-utf-8.csv', 'text.csv')).import
    end
    assert @customer.stores.map(&:name).include? 'Point 1'
  end

  test 'should import many-iso stores' do
    assert_difference('Store.count', 6) do
      assert ImportCsv.new(importer: ImporterStores.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_stores_many-iso.csv', 'text.csv')).import
    end
    assert @customer.stores.map(&:name).include? 'Point 1'
  end

  test 'should not import store' do
    assert_difference('Store.count', 0) do
      si = ImportCsv.new(importer: ImporterStores.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_invalid.csv', 'text.csv'))
      assert !si.import
      assert si.errors[:base][0] =~ /lignes \[2\]/
    end
  end

  test 'should update store' do
    assert_difference('Store.count', 1) do
      assert ImportCsv.new(importer: ImporterStores.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_stores_update.csv', 'text.csv')).import
    end
    assert_equal 'unaffected_one_update', Store.find_by(ref:'a').name
    assert_equal 'unaffected_two_update', Store.find_by(ref:'unknown').name
  end
end
