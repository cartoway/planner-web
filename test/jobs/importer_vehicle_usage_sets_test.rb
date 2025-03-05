require 'test_helper'

class ImporterVehicleUsageSetsTest < ActionController::TestCase
  setup do
    @customer = customers(:customer_one)
    Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options| segments.collect{ |i| [1, 1, '_ibE_seK_seK_seK'] } } ) do
      @customer.vehicle_usage_sets.reject{ |vu| vu == @vehicle_usage_set }.each(&:destroy)
      @customer.update_attribute(:max_vehicle_usage_sets, 1)
      @customer.reload
    end
  end

  def tempfile(file, name)
    file = fixture_file_upload(file)
    file
  end

  test 'should import vehicle usage set and reuse the current vehicle usage set' do
    assert_difference('VehicleUsageSet.count', 0) do
      assert_difference('VehicleUsage.count', 0) do
        assert_no_difference('Vehicle.count') do
          imported_data = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: true, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_one.csv', 'text.csv')).import

          assert imported_data
          assert_equal imported_data.count, 2
        end
      end
    end
  end

  test 'should import vehicle usage set and create a new vehicle usage set' do
    @customer.update_attribute(:max_vehicle_usage_sets, 2)

    assert_difference('VehicleUsageSet.count', 1) do
      assert_difference('VehicleUsage.count', 2) do
        assert_no_difference('Vehicle.count') do
          imported_data = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: true, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_one.csv', 'text.csv')).import

          assert imported_data
          assert_equal imported_data.count, 2
        end
      end
    end
  end

  test 'should import vehicles with same data and transfer them to the vehicle usage set' do
    assert_difference('VehicleUsageSet.count', 0) do
      assert_difference('VehicleUsage.count', 0) do
        assert_no_difference('Vehicle.count') do
          imported_data = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: true, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_with_identical_data.csv', 'text.csv')).import

          assert imported_data

          assert_equal imported_data.first.name, 'Véhicule 1'
          assert_nil imported_data.first.vehicle_usages.first.time_window_start
          assert_nil imported_data.first.vehicle_usages.first.time_window_end
          assert_nil imported_data.first.vehicle_usages.first.cost_distance
          assert_nil imported_data.first.vehicle_usages.first.cost_fixed
          assert_nil imported_data.first.vehicle_usages.first.cost_time

          assert_equal imported_data.second.name, 'Véhicule 2'
          assert_nil imported_data.second.vehicle_usages.first.time_window_start
          assert_nil imported_data.second.vehicle_usages.first.time_window_end
          assert_nil imported_data.second.vehicle_usages.first.cost_distance
          assert_nil imported_data.second.vehicle_usages.first.cost_fixed
          assert_nil imported_data.second.vehicle_usages.first.cost_time

          assert_equal @customer.vehicle_usage_sets.last.time_window_start, 26800
          assert_equal @customer.vehicle_usage_sets.last.time_window_end, 57600
          assert_equal @customer.vehicle_usage_sets.last.store_start.ref, 'b'
          assert_equal @customer.vehicle_usage_sets.last.cost_distance, 1
          assert_equal @customer.vehicle_usage_sets.last.cost_fixed, 2
          assert_equal @customer.vehicle_usage_sets.last.cost_time, 3
        end
      end
    end
  end

  test 'should import vehicle usage set and replace or not vehicles properties' do
    assert_difference('VehicleUsageSet.count', 0) do
      assert_no_difference('Vehicle.count') do
        imported_data = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: false, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_one.csv', 'text.csv')).import

        assert imported_data
        assert_equal imported_data.first.contact_email, 'toto@toto.toto'
        assert_equal imported_data.first.consumption, 1.5
        assert_nil imported_data.second.contact_email
        assert_nil imported_data.second.phone_number
        assert_equal imported_data.second.consumption, 1.5
      end
    end

    assert_difference('VehicleUsageSet.count', 0) do
      assert_no_difference('Vehicle.count') do
        imported_data = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: true, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_one.csv', 'text.csv')).import

        assert imported_data
        assert_equal imported_data.first.contact_email, 'vehicle1@example.com'
        assert_equal imported_data.first.consumption, 10
        assert_equal imported_data.first.phone_number, '0548484953'
        assert_equal imported_data.second.contact_email, 'vehicle2@example.com'
        assert_equal imported_data.second.consumption, 15
      end
    end
  end

  test 'should import vehicles with the same reference' do
    assert_difference('VehicleUsageSet.count', 0) do
      assert_no_difference('Vehicle.count') do
        imported_data = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: true, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_with_ref.csv', 'text.csv')).import

        assert imported_data
        assert_equal @customer.vehicles.first.ref, '001'
        assert_equal @customer.vehicles.first.contact_email, 'vehicle1@example.com'
        assert_equal @customer.vehicles.first.color, '#9000EE'

        assert_nil @customer.vehicles.second.ref
        assert_equal @customer.vehicles.second.contact_email, 'vehicle2@example.com'
      end
    end
  end

  test 'should import vehicle usage set with new capacities' do
    assert_difference('VehicleUsageSet.count', 0) do
      assert_difference('DeliverableUnit.count', 2) do
        imported_data = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: true, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_with_capacities.csv', 'text.csv')).import

        assert imported_data
        assert @customer.deliverable_units.map(&:label).include?('ton')
        assert @customer.deliverable_units.map(&:label).include?('gallon')
      end
    end
  end

  test 'should import vehicle usage set with custom router options' do
    assert_difference('VehicleUsageSet.count', 0) do
      imported_data = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: true, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_with_router_options.csv', 'text.csv')).import

      assert imported_data
      assert_equal imported_data.first.toll, true
      assert_equal imported_data.first.length, '1'
      assert_equal imported_data.second.toll, false
      assert_equal imported_data.second.length, '10'
      assert_equal imported_data.second.width, '3.55'
    end
  end

  test 'should import vehicle usage set with tags' do
    assert_difference('VehicleUsageSet.count', 0) do
      imported_data = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: true, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_with_tags.csv', 'text.csv')).import

      assert imported_data.first.tags.size, 1
      assert imported_data.second.vehicle_usages.first.tags.size, 1
    end
  end

  test 'should import vehicle usage set only once tag if twice have the same label' do
    assert_difference('VehicleUsageSet.count', 0) do
      imported_data = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: true, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_with_duplicated_tags.csv', 'text.csv')).import

      assert imported_data.first.tags.size, 1
      assert imported_data.second.vehicle_usages.first.tags.size, 1
    end
  end

  test 'should import vehicle usage set with custom devices' do
    assert_difference('VehicleUsageSet.count', 0) do
      imported_data = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: true, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_with_devices.csv', 'text.csv')).import

      assert imported_data
      assert_equal imported_data.first.trimble_ref, 'test'
      assert_equal imported_data.first.masternaut_ref, 'test'
      assert_equal imported_data.second.masternaut_ref, 'test'
      assert_nil imported_data.second.trimble_ref
    end
  end

  test 'should not import vehicle usage set without too many vehicles' do
    assert_difference('VehicleUsageSet.count', 0) do
      importer = ImportCsv.new(importer: ImporterVehicleUsageSets.new(@customer), replace_vehicles: true, file: tempfile('test/fixtures/files/import_vehicle_usage_sets_over_max_vehicles.csv', 'text.csv'))

      assert !importer.import
      assert_equal importer.errors[:file][0], I18n.t('destinations.import_file.too_many_lines', n: @customer.max_vehicles)
    end
  end
end
