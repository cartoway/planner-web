require 'test_helper'

class ImporterDestinationsTest < ActionController::TestCase
  setup do
    @customer = customers(:customer_one)
    @visit_tag1_count = @customer.visits.select{ |v| v.tags.include? tags(:tag_one) }.size
    @plan_tag1_count = @customer.plannings.select{ |p| p.tags_compatible? [tags(:tag_one)] }.size
  end

  def around
    Location.stub_any_instance(:geocode, lambda{ |*a| puts 'Geocode destination without using bulk!'; raise }) do
      Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |url, mode, dimension, segments, options|
          segments.collect{ |i|
            i[0] == i[2] && i[1] == i[3] ? [0, 0, '_ibE_seK_seK_seK'] : [1, 1, '_ibE_seK_seK_seK']
          }
        }) do
        Routers::Osrm.stub_any_instance(:matrix, lambda{ |url, vector| Array.new(vector.size, Array.new(vector.size, 0)) }) do
          yield
        end
      end
    end
  end

  def tempfile(file, name)
    file = ActionDispatch::Http::UploadedFile.new({
      tempfile: File.new(Rails.root.join(file)),
    })
    file.original_filename = name
    file
  end

  test 'should not import' do
    assert_no_difference('Destination.count') do
      assert_no_difference('Visit.count') do
        di = ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_invalid.csv', 'text.csv'))
        assert !di.import
        assert di.errors[:base][0] =~ /ligne 2/
      end
    end
  end

  test 'should import' do
    without_loading Planning do
      without_loading Stop do
        assert_difference('Destination.count', 1) do
          assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one_without_ref.csv', 'text.csv')).import
        end
      end
    end
  end

  test 'should replace with new tag' do
    assert_difference('Tag.count') do
      assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: true, file: tempfile('test/fixtures/files/import_destinations_new_tag.csv', 'text.csv')).import
      assert_equal 1, @customer.destinations.size
      assert_equal 1, @customer.destinations.collect{ |d| d.visits.size }.reduce(&:+)
    end
  end

  test 'should import only once tag if twice have the same label' do
    assert_difference('Tag.count', 2) do
      assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: true, file: tempfile('test/fixtures/files/import_destinations_with_duplicated_tag.csv', 'text.csv')).import
      assert_equal 1, @customer.destinations.size
    end
  end

  test 'should import only ref in new planning' do
    # clean all visit ref to update the first destination's visit without ref during import
    Visit.all.each{ |v| v.update! ref: nil }
    @customer.reload
    # destinations with same ref are merged
    import_count = 0
    # vehicle_usage_set for new planning is hardcoded but random in tests... rest_count depends of it
    VehicleUsageSet.all.each { |v| v.destroy if v.id != vehicle_usage_sets(:vehicle_usage_set_one).id }
    rest_count = @customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.default_rest_duration }.size
    assert_difference('Planning.count', 1) do
      assert_difference('Destination.count', import_count) do
        assert_difference('Stop.count', (@visit_tag1_count + (import_count * (@plan_tag1_count + 1)) + rest_count)) do
          # The imported destination had no tag before import, but its visit had tag1
          # The visit have no ref, it will be updated by the import having no ref neither
          # The new plan should have all the others visits having tag1 and the one associated to the imported destination
          # The previously plans should not have new visit
          assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_only_ref.csv', 'text.csv')).import
          assert_equal 49.1857, @customer.destinations.find{ |d| d.ref == 'b' }.lat
        end
      end
    end
  end

  test 'should import without ref' do
    import_count = 1
    dest = nil
    assert_difference('Destination.count', import_count) do
      assert_difference('Visit.count', import_count) do
        assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one_without_ref.csv', 'text.csv')).import
        dest = Destination.last
      end
    end
    # new import of same data without ref should create a new destination and new visit
    assert_difference('Destination.count', import_count) do
      assert_difference('Visit.count', import_count) do
        assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one_without_ref.csv', 'text.csv')).import
        assert_equal dest.attributes, dest.reload.attributes
      end
    end
  end

  test 'should import without ref and multi visit' do
    @customer.update! enable_multi_visits: true # Move dest.ref to visit.ref !
    @customer.reload # Force reload after callback save

    import_count = 1
    dest = nil
    assert_difference('Destination.count', import_count) do
      assert_difference('Visit.count', import_count) do
        assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one_without_ref.csv', 'text.csv')).import
        dest = Destination.last
      end
    end
    # new import of same data without ref should create a new visit for existing destination
    assert_no_difference('Destination.count') do
      assert_difference('Visit.count', import_count) do
        assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one_without_ref.csv', 'text.csv')).import
        assert_equal dest.attributes, dest.reload.attributes
      end
    end
  end

  test 'should import in new planning' do
    import_count = 1
    # vehicle_usage_set for new planning is hardcoded but random in tests... rest_count depends of it
    VehicleUsageSet.all.each { |v| v.destroy if v.id != vehicle_usage_sets(:vehicle_usage_set_one).id }
    rest_count = @customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.default_rest_duration }.size
    assert_difference('Planning.count', 1) do
      assert_difference('Destination.count', import_count) do
        assert_difference('Stop.count', (@visit_tag1_count + (import_count * (@plan_tag1_count + 1)) + rest_count)) do
          assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one.csv', 'text.csv')).import

          visit = Visit.last
          assert_equal 1.23, visit.quantities[1]
          assert_equal 'fill', visit.quantities_operations[1]
          assert_nil visit.priority

          stop = Planning.last.routes.collect{ |r| r.stops.find{ |s| s.is_a?(StopVisit) && s.visit.destination.name == 'BF' } }.compact.first
          assert_equal true, stop.active
          if stop.route.vehicle_usage.default_store_start.position?
            assert_equal 1, stop.distance
          else
            assert_equal 0, stop.distance
          end
        end
      end
    end

    assert_equal [tags(:tag_one)], Destination.where(name: 'BF').first.visits.first.destination.tags.to_a
  end

  test 'should import postalcode in new planning' do
    dest = nil
    import_count = 1
    # vehicle_usage_set for new planning is hardcoded but random in tests... rest_count depends of it
    VehicleUsageSet.all.each { |v| v.destroy if v.id != vehicle_usage_sets(:vehicle_usage_set_one).id }
    rest_count = @customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.default_rest_duration }.size
    assert_difference('Planning.count', 1) do
      assert_difference('Destination.count', import_count) do
        assert_difference('Stop.count', (@visit_tag1_count + (import_count * (@plan_tag1_count + 1)) + rest_count)) do
          assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one_postalcode.csv', 'text.csv')).import
          dest = @customer.destinations.find{ |d| d.ref == 'z' }
          assert_equal 1, dest.lat # code_bulk result is lat=1.0, code only one result is lat=44.850154
        end
      end
    end
    dest.update postalcode: 13000, lat: 2, lng: 2
    # dest should be geocoded again with a new import
    assert_difference('Planning.count', 1) do
      assert_no_difference('Destination.count') do
        assert_difference('Stop.count', (@visit_tag1_count + import_count + rest_count)) do
          assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one_postalcode.csv', 'text.csv')).import
          dest.reload
          assert_equal 1, dest.lat # code_bulk result is lat=1.0, code only one result is lat=44.850154
        end
      end
    end
  end

  test 'should import coord in new planning' do
    import_count = 1
    # vehicle_usage_set for new planning is hardcoded but random in tests... rest_count depends of it
    VehicleUsageSet.all.each { |v| v.destroy if v.id != vehicle_usage_sets(:vehicle_usage_set_one).id }
    rest_count = @customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.default_rest_duration }.size
    assert_difference('Planning.count', 1) do
      assert_difference('Destination.count', import_count) do
        assert_difference('Stop.count', (@visit_tag1_count + (import_count * (@plan_tag1_count + 1)) + rest_count)) do
          assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one_coord.csv', 'text.csv')).import
        end
      end
    end
  end

  test 'should import two in new planning' do
    import_count = 2
    # vehicle_usage_set for new planning is hardcoded but random in tests... rest_count depends of it
    VehicleUsageSet.all.each { |v| v.destroy if v.id != vehicle_usage_sets(:vehicle_usage_set_one).id }
    rest_count = @customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.default_rest_duration }.size
    assert_difference('Planning.count', 1) do
      assert_difference('Destination.count', import_count) do
        assert_difference('Stop.count', (@visit_tag1_count + (import_count * (@plan_tag1_count + 1)) + rest_count)) do
          assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_two.csv', 'text.csv')).import
        end
      end
    end

    stops = Planning.where(name: 'text').first.routes.find{ |route| route.ref == '1' }.stops
    assert_equal 'z', stops[1].visit.destination.ref
    assert stops[1].visit.duration
    assert stops[1].active
    assert_equal 'x', stops[2].visit.destination.ref
    assert_not stops[2].active
  end

  test 'should import without visit' do
    dest_import_count = 2
    visit_tag1_import_count = 1
    assert_no_difference('Planning.count') do
      assert_difference('Destination.count', dest_import_count) do
        assert_difference('Stop.count', visit_tag1_import_count * @plan_tag1_count) do
          assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_without_visit.csv', 'text.csv')).import
        end
      end
    end
  end

  test 'should import many-utf-8 in new planning' do
    Planning.all.each(&:destroy)
    planning = @customer.plannings.build(name: 'plan été', vehicle_usage_set: vehicle_usage_sets(:vehicle_usage_set_one), tags: [@customer.tags.build(label: 'été')])
    planning.default_routes
    planning.save!
    @customer.reload
    @customer.delete_all_destinations
    # destinations with same ref throw an error
    import_count = 5
    # vehicle_usage_set for new planning is hardcoded but random in tests... rest_count depends of it
    VehicleUsageSet.all.each { |v| v.destroy if v.id != vehicle_usage_sets(:vehicle_usage_set_one).id }
    rest_count = @customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.default_rest_duration }.size

    assert_difference('Planning.count', 1) do
      assert_difference('Destination.count', import_count) do
        assert_difference('Stop.count', import_count * (@customer.plannings.select{ |p| p.tags.any?{ |t| t.label == 'été' } }.size + 1) + rest_count) do
          di = ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_many-utf-8.csv', 'text.csv'))
          assert di.import, di.errors.messages
          assert_equal 'été', @customer.plannings.map{ |p| p.tags.map(&:label).empty? ? 'oups' : p.tags.map(&:label).join }.join
        end
      end
    end

    o = Destination.find_by(name: 'Point 1')
    assert_equal ['été'], o.visits.first.destination.tags.collect(&:label)
    p = Planning.first
    assert_equal import_count, p.routes[0].stops.size
    p = Planning.last
    assert_equal 2, p.routes[0].stops.size
    assert_equal 4, p.routes[1].stops.size
    refute_includes Planning.last.routes.map(&:outdated), true
  end

  test 'should import many-iso' do
    Planning.all.each(&:destroy)
    @customer.delete_all_destinations
    assert_difference('Destination.count', 5) do
      assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_many-iso.csv', 'text.csv')).import

      o = Destination.find_by(name: 'Point 1')
      assert_equal ['été'], o.tags.collect(&:label)
    end
  end

  test 'should import with many visits' do
    @customer.update! enable_multi_visits: true # Move dest.ref to visit.ref !
    @customer.reload # Force reload after callback save

    dest_import_count = 6
    visit_import_count = 7
    visit_tag1_import_count = 1
    visit_tag2_import_count = 3
    assert_no_difference('Planning.count') do
      assert_difference('Destination.count', dest_import_count) do
        assert_difference('Stop.count',
          visit_import_count * @customer.plannings.select{ |p| p.tags == [] }.size +
          visit_tag1_import_count * @plan_tag1_count +
          visit_tag2_import_count * @customer.plannings.select{ |p| p.tags == [tags(:tag_two)] }.size) do
          assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_with_many_visits.csv', 'text.csv')).import
        end
      end
    end
  end

  test 'should replace with many visits' do
    @customer.update! enable_multi_visits: true # Move dest.ref to visit.ref !
    dest_import_count = 5 # 5 uniq ref
    visit_import_count = 7
    visit_tag1_import_count = 1
    visit_tag2_import_count = 3
    stop_visit_count = @customer.plannings.collect{ |p| p.routes.collect{ |r| r.stops.select{ |s| s.is_a?(StopVisit) }.size }.reduce(&:+) }.reduce(&:+)
    assert_no_difference('Planning.count') do
      assert_difference('Stop.count', visit_import_count * @customer.plannings.select{ |p| p.tags == [] }.size + # 0
          visit_tag1_import_count * @plan_tag1_count +
          visit_tag2_import_count * @customer.plannings.select{ |p| p.tags == [tags(:tag_two)] }.size -
          stop_visit_count) do
        assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: true, file: tempfile('test/fixtures/files/import_destinations_with_many_visits.csv', 'text.csv')).import
        assert_equal dest_import_count, @customer.destinations.size
      end
    end
  end

  test 'should import and update' do
    destinations(:destination_unaffected_one).update(lat: 2.5, lng: 2.5, geocoding_accuracy: 0.9, geocoding_level: :house) && @customer.reload
    assert_difference('Destination.count', 1) do
      assert_difference('Visit.count', 1) do
        assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_update.csv', 'text.csv')).import
      end
    end
    destination = Destination.find_by(ref:'a')
    assert_equal 'unaffected_one_update', destination.name
    assert_equal 1.5, destination.lat
    assert_nil destination.geocoding_accuracy
    assert_equal 'point', destination.geocoding_level
    assert_equal [[1]], destination.visits.map{ |v| v.quantities.values }
    assert_equal 'unaffected_two_update', Destination.find_by(ref:'unknown').visits.first.name

    assert_no_difference('Destination.count') do
      # should import without need geocode (postalcode should be nilified and unchanged)
      assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_update.csv', 'text.csv')).import
      destination = Destination.find_by(ref:'a')
      assert_equal 1.5, destination.lat
    end
  end

  test 'should import with route error in new planning' do
    import_count = 2
    # vehicle_usage_set for new planning is hardcoded but random in tests... rest_count depends of it
    VehicleUsageSet.all.each { |v| v.destroy if v.id != vehicle_usage_sets(:vehicle_usage_set_one).id }
    rest_count = @customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.default_rest_duration }.size
    assert_difference('Planning.count') do
      assert_difference('Destination.count', import_count) do
        assert_difference('Stop.count', (@visit_tag1_count + (import_count * (@plan_tag1_count + 1)) + rest_count)) do
          RouterOsrm.stub_any_instance(:trace, lambda{ |*a| raise(RouterError.new('{"status":400,"status_message":"No route found between points"}')) }) do
            assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_two.csv', 'text.csv')).import
          end
        end
      end
    end

    stops = Planning.where(name: 'text').first.routes.find{ |route| route.ref == '1' }.stops
    assert_equal 'z', stops[1].visit.destination.ref
    assert stops[1].visit.duration
    assert stops[1].active
    assert_equal 'x', stops[2].visit.destination.ref
    assert_not stops[2].active
  end

  test 'should import postalcode in new planning with geocode error' do
    import_count = 1
    # vehicle_usage_set for new planning is hardcoded but random in tests... rest_count depends of it
    VehicleUsageSet.all.each { |v| v.destroy if v.id != vehicle_usage_sets(:vehicle_usage_set_one).id }
    rest_count = @customer.vehicle_usage_sets[0].vehicle_usages.select{ |v| v.default_rest_duration }.size
    assert_difference('Planning.count', 1) do
      assert_difference('Destination.count', import_count) do
        assert_difference('Stop.count', (@visit_tag1_count + (import_count * (@plan_tag1_count + 1)) + rest_count)) do
          Mapotempo::Application.config.geocoder.class.stub_any_instance(:code_bulk, lambda{ |*a| raise GeocodeError.new }) do
            assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one_postalcode.csv', 'text.csv')).import
          end
        end
      end
    end
  end

  test 'should not import many-iso due to multi-refs error' do
    Planning.all.each(&:destroy)
    @customer.delete_all_destinations
    assert_difference('Destination.count', 0) do
        error = I18n.t('destinations.import_file.refs_duplicate', refs: "réf5")
        destinations_import = ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_multi_refs.csv', 'text.csv'))
        assert_equal false, destinations_import.import
        assert_equal true, Rails.logger.error
        assert_equal error, destinations_import.errors.messages[:base][0].scan(error)[0]
    end
  end

  test 'should not import too many routes' do
    assert_no_difference('Destination.count') do
      assert_no_difference('Visit.count') do
        di = ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_too_many_routes.csv', 'text.csv'))
        assert !di.import
        assert di.errors[:base][0] =~ /plus de tournées que de véhicules disponibles/
      end
    end
  end

  test 'should import by merging columns' do
    import_count = 1
    assert_difference('Destination.count', import_count) do
      assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, column_def: {name: 'code postal, nom'}, file: tempfile('test/fixtures/files/import_destinations_one.csv', 'text.csv')).import
    end

    o = Destination.where(ref: 'z').first
    assert_equal '13010 BF', o.name
    assert_equal '13010', o.postalcode
  end

  test 'should import without header' do
    assert_no_difference('Planning.count') do
      assert_difference('Destination.count', 1) do
        assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, column_def: {name: '2,3', city: '4', lat: '5', lng: '6', tags: '7'}, file: tempfile('test/fixtures/files/import_destinations_without_header.csv', 'text.csv')).import
      end
    end

    o = Destination.find_by(name: 'Point 1')
    assert_equal ['été'], o.tags.collect(&:label)
  end

  test 'should import without header and error column def' do
    assert_no_difference('Planning.count') do
      assert_difference('Destination.count', 1) do
        assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, column_def: {ref: '10000', name: '2,3', city: '4', lat: '5', lng: '6', tags: '7'}, file: tempfile('test/fixtures/files/import_destinations_without_header.csv', 'text.csv')).import
      end
    end

    o = Destination.find_by(name: 'Point 1')
    assert_equal ['été'], o.tags.collect(&:label)
  end

  test 'should not import without header and error column def' do
    assert_no_difference('Destination.count') do
      assert_no_difference('Visit.count') do
        assert !ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, column_def: {ref: '10000'}, file: tempfile('test/fixtures/files/import_destinations_without_header.csv', 'text.csv')).import
      end
    end
  end

  test 'should import deprecated columns' do
    assert_no_difference('Planning.count') do
      assert_difference('Visit.count', 1) do
        assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_deprecated_columns.csv', 'text.csv')).import
      end
    end

    assert_equal '15:00', Visit.last.time_window_start_1_time
  end

  test 'should import destinations with locale number separator (commas in french)' do
    orig_locale = I18n.locale
    begin
      [:en, :fr].each do |locale|
        I18n.locale = locale
        assert_difference('Destination.count', 1) do
          ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile("test/fixtures/files/import_destinations_#{locale.to_s.upcase}.csv", "text.csv")).import
        end
        assert 49.173419, Destination.last.lat
        assert -0.326613, Destination.last.lng
        assert_equal 39.482, Visit.last.quantities[2]
      end
    ensure
      I18n.locale = orig_locale
    end
  end

  test 'should import destinations CSV file with spaces in headers' do
    assert_difference('Destination.count', 1) do
      ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_headers_with_spaces.csv', 'text.csv')).import
    end
  end

  test 'should import blank CSV file' do
    assert_no_difference('Destination.count', 1) do
      ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/blank.csv', 'text.csv')).import
    end
  end

  test 'should import without end or begin datetime' do
    import_count = 3
    assert_difference('Destination.count', import_count) do
      import = ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one_time_missing.csv', 'text.csv'))
      import.import
    end
  end

  test 'should import then add geojson and quantities to route' do
    assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one.csv', 'text.csv')).import

    routes = Planning.last.routes
    routes.each do |route|
      route.geojson_points.each do |line_string|
        decoded_line_string = JSON.parse(line_string)
        assert_not_nil decoded_line_string['properties']['route_id']
      end

      route.geojson_tracks.each do |point|
        decoded_point = JSON.parse(point)
        assert_not_nil decoded_point['properties']['route_id']
      end if route.geojson_tracks

      assert_not route.quantities.to_s.blank?
    end
  end

  test 'should use limitation' do
    @customer.max_plannings = @customer.plannings.size
    @customer.save!

    assert_difference('Planning.count', 0) do
      assert_difference('Route.count', 0) do
        import = ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_one.csv', 'text.csv'))
        assert_not import.import
        assert_equal 'Dépassement du nombre maximal de plans', import.errors.full_messages.join('')
      end
    end
  end

  test 'should import without error after update' do
    @customer.update!(enable_multi_visits: true)
    @customer.reload

    Planning.all.each(&:destroy)
    @customer.tags.all.each(&:destroy)
    @customer.reload
    @customer.delete_all_destinations

    import_init = ImportCsv.new(importer: ImporterDestinations.new(@customer, {}), replace: true, file: tempfile('test/fixtures/files/import_destinations_ref_and_tags_init.csv', 'text.csv'))
    import_init.import

    @customer.reload

    import_update = ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: false, file: tempfile('test/fixtures/files/import_destinations_ref_and_tags_update.csv', 'text.csv'))

    # Import return value must contain updated destinations. Otherwise a stale error on route object is raised (in log only because it catch in import CSV).
    assert import_update.import

    # Ensure route is flagged outdated
    assert @customer.plannings.last.routes.first.outdated?
  end

  test 'should fail with error if stop type is incorrect' do
    import = ImportCsv.new(
      importer: ImporterDestinations.new(@customer, {}),
      replace: true,
      file: tempfile('test/fixtures/files/import_destinations_incorrect_stop_type.csv', 'text.csv')
    )

    refute import.import
    assert import.errors[:base][0] =~ /Le type d'arrêt n'est pas valide/
  end

  test 'should import several plans from one file' do
    Planning.all.each(&:destroy)
    @customer.delete_all_destinations
    assert_difference('Planning.count', 3) do
      stops_count = 5 + 3 + 3 + 3 # visits plan1 + plan2 + plan3 + rests
      assert_difference('Stop.count', stops_count) do
        assert ImportCsv.new(importer: ImporterDestinations.new(@customer), replace: true, file: tempfile('test/fixtures/files/import_destinations_several_plans.csv', 'text.csv')).import

        @customer.reload

        assert_equal [['été'], ['été', 'hiver'], ['été', 'hiver']], @customer.plannings.map{ |p| p.tags.map(&:label) }
      end
    end
  end

end
