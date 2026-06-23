# frozen_string_literal: true

require 'test_helper'

class ImporterDestinationsPlanningStateTest < ActionController::TestCase
  setup do
    @customer = customers(:customer_one)
    @customer.update!(enable_store_stops: true)
    stops(:stop_three_one).destroy
    PlanningState.delete_all
  end

  def around
    Location.stub_any_instance(:geocode, lambda { |*_args| raise }) do
      Routers::RouterWrapper.stub_any_instance(:compute_batch, lambda { |_url, _mode, _dimension, segments, _options|
        segments.collect do |segment|
          segment[0] == segment[2] && segment[1] == segment[3] ? [0, 0, '_ibE_seK_seK_seK'] : [1, 1, '_ibE_seK_seK_seK']
        end
      }) do
        Routers::Osrm.stub_any_instance(:matrix, lambda { |_url, vector|
          Array.new(vector.size) { Array.new(vector.size, 0) }
        }) do
          yield
        end
      end
    end
  end

  def tempfile(file, name)
    file = ActionDispatch::Http::UploadedFile.new({
      tempfile: File.new(Rails.root.join(file))
    })
    file.original_filename = name
    file
  end

  test 'import captures planning state for new and updated plannings' do
    Planning.all.each(&:destroy)
    @customer.delete_all_destinations
    @customer.vehicle_usage_sets.each { |vus| vus.vehicle_usages.each { |vu| vu.update!(active: true) } }
    @customer.reload

    assert_difference('PlanningState.count', 1) do
      assert ImportCsv.new(
        importer: ImporterDestinations.new(@customer),
        replace: true,
        file: tempfile('test/fixtures/files/import_destinations_single_plan_two_routes.csv', 'text.csv')
      ).import
    end

    @customer.reload
    planning = @customer.plannings.last
    state = planning.planning_states.where(trigger: 'import').order(:id).last
    assert_equal 'import', state.trigger
    assert_equal 'mass', state.category

    assert_difference('PlanningState.count', 1) do
      assert ImportCsv.new(
        importer: ImporterDestinations.new(@customer),
        replace: false,
        file: tempfile('test/fixtures/files/import_destinations_single_plan_one_route_v2v1.csv', 'text.csv')
      ).import
    end

    planning.reload
    import_states = planning.planning_states.where(trigger: 'import').order(:id)
    assert_equal 2, import_states.count
    assert_equal 'import', import_states.last.trigger
  end
end
