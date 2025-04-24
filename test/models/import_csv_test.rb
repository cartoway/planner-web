require 'test_helper'

class ImportCsvTest < ActiveSupport::TestCase
  setup do
    @importer = ImporterDestinations.new(customers(:customer_one))
  end

  test 'should upload' do
    file = Rack::Test::UploadedFile.new('test/fixtures/files/import_stores_one.csv')
    import_csv = ImportCsv.new(importer: @importer, replace: false, file: file)
    assert import_csv.valid?
  end

  test 'shoud not import too many destinations' do
    importer_destinations = ImporterDestinations.new(@customer)
    def importer_destinations.max_lines
      2
    end

    file = Rack::Test::UploadedFile.new('test/fixtures/files/import_destinations_many-utf-8.csv')
    assert_difference('Destination.count', 0) do
      assert !ImportCsv.new(importer: importer_destinations, replace: false, file: file).import
    end
  end

  test 'shoud not import without file' do
    assert_difference('Destination.count', 0) do
      assert !ImportCsv.new(importer: @importer, replace: false, file: nil).import
    end
  end

  test 'shoud not import invalid' do
    file = Rack::Test::UploadedFile.new('test/fixtures/files/import_invalid.csv')
    assert_difference('Destination.count', 0) do
      o = ImportCsv.new(importer: @importer, replace: false, file: file)
      assert !o.import
      assert o.errors[:base][0].match('lignes \[2\]')
      assert o.errors[:base][0].match('Le code postal et la ville ne peuvent pas être vides si lat\/lng sont vides')
    end
  end

  test 'should upload plan when vehicle number is less or equal to maximum allowed' do
    stub_request(:post, %r{/0.1/routes.json}).to_return(status: 200)
    file = Rack::Test::UploadedFile.new('test/fixtures/files/import_more_route_than_vehicle.csv')
    customer = customers(:customer_one_other)
    customer.update(max_vehicles: 1)
    @importer = ImporterDestinations.new(customer)
    import_csv = ImportCsv.new(importer: @importer, replace: true, file: file)

    assert_not import_csv.import
    assert_equal I18n.t('errors.planning.import_too_many_routes'), import_csv.errors.messages[:base].first
  end

  test 'should upload plan when vehicle number is equal to maximum allowed and destinations are not affected' do
    stub_request(:post, %r{/0.1/routes.json}).to_return(status: 200)
    file = Rack::Test::UploadedFile.new('test/fixtures/files/import_enough_route_for_vehicle_and_destination_not_affected.csv')
    customer = customers(:customer_one_other)
    customer.update(max_vehicles: 1)
    @importer = ImporterDestinations.new(customer)
    import_csv = ImportCsv.new(importer: @importer, replace: true, file: file)

    assert import_csv.import
  end

  test 'should geocode customers even with specific columns' do
    destination = Destination.create(
      customer: customers(:customer_one),
      name: 'Place Picard', postalcode: '33000',
      city: 'Bordeaux', lat: 44.837663, lng: -0.579717,
      geocoding_accuracy: 0.98, geocoding_level: 5, ref: 'p-12'
    )

    file2 = Rack::Test::UploadedFile.new('test/fixtures/files/import_customers_and_geocode.csv')
    import_csv = ImportCsv.new(importer: @importer, replace: false, file: file2, column_def: { name: 'name' })
    import_csv.import

    # must have pass by code_bulk method
    assert_equal 1.0, destination.reload.lat
    assert_equal 1.0, destination.reload.lng
  end

  test 'should geocode customers even with specific lat/lng name' do
    destination = Destination.create(
        customer: customers(:customer_one),
        name: 'Place Picard', postalcode: '33000',
        city: 'Bordeaux', lat: 44.837663, lng: -0.579717,
        geocoding_accuracy: 0.98, geocoding_level: 5, ref: 'p-12'
    )

    file2 = Rack::Test::UploadedFile.new('test/fixtures/files/import_customers_with_specific_columns_name.csv')
    import_csv = ImportCsv.new(importer: @importer, replace: false, file: file2, column_def: { name: 'name', lat: 'latitude', lng: 'longitude' })
    import_csv.import

    # must have pass by code_bulk method
    assert_equal 1.0, destination.reload.lat
    assert_equal 1.0, destination.reload.lng
  end

  test 'should not geocode customers with specific columns when no lat/lng' do
    destination = Destination.create(
      customer: customers(:customer_one),
      name: 'Place Picard', postalcode: '33000',
      city: 'Bordeaux', lat: 44.837663, lng: -0.579717,
      geocoding_accuracy: 0.98, geocoding_level: 5, ref: 'p-12'
    )

    file2 = Rack::Test::UploadedFile.new('test/fixtures/files/import_customers_and_do_not_geocode.csv')
    import_csv = ImportCsv.new(importer: @importer, replace: false, file: file2, column_def: { name: 'name' })
    import_csv.import

    # must have pass by code_bulk method
    assert_not_equal 1.0, destination.reload.lat
    assert_not_equal 1.0, destination.reload.lng
  end

  test 'should geocode even if lat/lng not not specified in column def' do
    destination = Destination.create(
        customer: customers(:customer_one),
        name: 'Place Picard', postalcode: '33000',
        city: 'Bordeaux', lat: 44.837663, lng: -0.579717,
        geocoding_accuracy: 0.98, geocoding_level: 5, ref: 'p-12'
    )

    file2 = Rack::Test::UploadedFile.new('test/fixtures/files/import_destination_special_lat_lng.csv')
    import_csv = ImportCsv.new(importer: @importer, replace: false, file: file2, column_def: { name: 'name', lat: 'latitude', lng: 'longitude' })
    import_csv.import

    # must have pass by code_bulk method
    assert_equal 1.0, destination.reload.lat
    assert_equal 1.0, destination.reload.lng
  end

  test 'should import destinations with empty lines in FR locale' do
    I18n.locale = :fr

    stub_request(:post, %r{/0.1/routes.json}).to_return(status: 200)

    file = Rack::Test::UploadedFile.new('test/fixtures/files/import_destinations_with_empty_lines.csv')
    import_csv = ImportCsv.new(file: file, importer: @importer, content_code: :html, replace: false, delete_plannings: false)

    assert import_csv.valid?
    expected_result = [{ ref: :"C0007-1", name: "CARREFOUR PONTAULT-COMBAULT - FRA084 POUR LUSIFOOD", street: "RN4", detail: nil, geocoding_result: {}, geocoding_accuracy: nil, geocoding_level: 1, postalcode: "77340", city: "PONTAULT-COMBAULT", duration: nil, lat: 48.776156, lng: 2.610715, phone_number: "164434720", comment: nil, customer_id: customers(:customer_one).id }]
    assert_equal expected_result, import_csv.import.compact.map { |h| h.sort.to_h }

    I18n.locale = I18n.default_locale
  end

  test 'should import destinations in EN locale' do
    I18n.locale = :en

    file = Rack::Test::UploadedFile.new('test/fixtures/files/import_destinations_EN.csv')
    import_csv = ImportCsv.new(file: file, importer: @importer, content_code: :html, replace: false, delete_plannings: false)

    assert import_csv.valid?
    expected_result = [{ city: "PARIS 12", comment: nil, country: nil, customer_id: customers(:customer_one).id, detail: nil, duration: nil, lat: 49.173419, lng: -0.326613, name: "LEPAGE JEONG", phone_number: "610549758", postalcode: "75012", ref: nil, street: "7ter Rue du Colonel Oudot" }]
    assert_equal expected_result, import_csv.import.map { |h| h.sort.to_h }

    I18n.locale = I18n.default_locale
  end
end
