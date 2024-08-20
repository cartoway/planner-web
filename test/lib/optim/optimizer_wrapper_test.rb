require 'test_helper'

require 'optim/optimizer_wrapper'

class OptimizerWrapperTest < ActionController::TestCase
  setup do
    @optim = OptimizerWrapper.new(ActiveSupport::Cache::NullStore.new, 'http://localhost:1791/0.1', 'demo')

    uri_template = Addressable::Template.new('http://localhost:1791/0.1/vrp/submit.json')
    @stub_VrpSubmit = stub_request(:post, uri_template).to_return(status: 200, body: File.new(File.expand_path('../../', __dir__) + '/fixtures/optimizer-wrapper/vrp-submit.json').read)

    uri_template = Addressable::Template.new('http://localhost:1791/0.1/vrp/jobs/{job_id}.json?api_key={api_key}')
    @stub_VrpJob = stub_request(:get, uri_template).to_return(status: 200, body: File.new(File.expand_path('../../', __dir__) + '/fixtures/optimizer-wrapper/vrp-job.json').read)

    @planning = plannings(:planning_one)
  end

  test 'should optimize' do
    begin
      OptimizerWrapper.stub_any_instance(:build_vrp, JSON.parse(File.new(File.expand_path('../../', __dir__) + '/fixtures/optimizer-wrapper/submitted-vrp.json').read, symbolize_names: true)) do
        routes = @planning.routes.select{ |route| route.vehicle_usage? }
        assert_equal [[1, 2, 3, 4, 5], []], @optim.optimize(@planning, routes, optimize_minimal_time: 3)
      end
    ensure
      remove_request_stub(@stub_VrpJob)
      remove_request_stub(@stub_VrpSubmit)
    end
  end

  test 'should build relation' do
    begin
      vrp = @optim.build_vrp(@planning, @planning.routes)
      refute_empty vrp[:relations]
    ensure
      remove_request_stub(@stub_VrpJob)
      remove_request_stub(@stub_VrpSubmit)
    end
  end

  test 'should build vehicles using vehicle_usage_set' do
    begin
      store_one = stores(:store_one)
      routes_with_vehicles = @planning.routes.select(&:vehicle_usage)
      routes_with_vehicles.each{ |route|
        route.vehicle_usage.update(
          time_window_start: nil,
          time_window_end: nil,
          work_time: nil,
          store_start: nil,
          store_stop: nil
        )
        route.vehicle_usage.vehicle.update(
          max_distance: nil,
          max_ride_duration: nil,
          max_ride_distance: nil
        )

        route.vehicle_usage.vehicle_usage_set.update(
          time_window_start: 10,
          time_window_end: 150,
          work_time: 360,
          store_start: store_one,
          store_stop: store_one,
          max_distance: 1000,
          max_ride_duration: 36,
          max_ride_distance: 100
        )
      }

      vrp = @optim.build_vrp(@planning, @planning.routes)

      vrp[:vehicles].each { |vehicle|
        assert_equal 10, vehicle[:timewindow][:start]
        assert_equal 150, vehicle[:timewindow][:end]
        assert_equal 360, vehicle[:duration]
        assert_equal 1000, vehicle[:distance]
        assert_equal 36, vehicle[:maximum_ride_time]
        assert_equal 100, vehicle[:maximum_ride_distance]
        assert_equal "d#{store_one.id}", vehicle[:start_point_id]
        assert_equal "d#{store_one.id}", vehicle[:end_point_id]
      }
    end
  ensure
    remove_request_stub(@stub_VrpJob)
    remove_request_stub(@stub_VrpSubmit)
  end

  test 'should build vehicles' do
    begin
      routes_with_vehicles = @planning.routes.select(&:vehicle_usage)
      store_one = stores(:store_one)

      routes_with_vehicles.each{ |route|

        route.vehicle_usage.update(
          time_window_start: 10,
          time_window_end: 150,
          work_time: 360,
          store_start: store_one,
          store_stop: store_one
        )
        route.vehicle_usage.vehicle.update(
          max_distance: 1000,
          max_ride_duration: 36,
          max_ride_distance: 100
        )
      }
      vrp = @optim.build_vrp(@planning, @planning.routes)
      assert_equal routes_with_vehicles.size, vrp[:vehicles].size
      vrp[:vehicles].each { |vehicle|
        assert_equal 10, vehicle[:timewindow][:start]
        assert_equal 150, vehicle[:timewindow][:end]
        assert_equal 360, vehicle[:duration]
        assert_equal 1000, vehicle[:distance]
        assert_equal 36, vehicle[:maximum_ride_time]
        assert_equal 100, vehicle[:maximum_ride_distance]
        assert_equal "d#{store_one.id}", vehicle[:start_point_id]
        assert_equal "d#{store_one.id}", vehicle[:end_point_id]
      }
    end
  ensure
    remove_request_stub(@stub_VrpJob)
    remove_request_stub(@stub_VrpSubmit)
  end

  test 'should build services' do
    begin
      stops = @planning.routes.flat_map{ |route| route.stops.select{ |stop| stop.is_a?(StopVisit) } }
      rest_stop = @planning.routes.select{ |route| route.vehicle_usage&.store_rest_id }

      vrp = @optim.build_vrp(@planning, @planning.routes)
      assert_equal stops.size + rest_stop.size, vrp[:services].size
      stops.each.with_index{ |stop, index|
        assert vrp[:services][index]
        assert_equal stop.time_window_start_1, vrp[:services][index][:activity][:timewindows][0][:start]
        assert_equal stop.time_window_end_1, vrp[:services][index][:activity][:timewindows][0][:end]
      }
    end
  ensure
    remove_request_stub(@stub_VrpJob)
    remove_request_stub(@stub_VrpSubmit)
  end

  test 'should return error if work time is not acceptable' do
    begin
      optim = OptimizerWrapper.new(ActiveSupport::Cache::NullStore.new, 'http://localhost:1791/0.1', 'demo')

      uri_template = Addressable::Template.new('http://localhost:1791/0.1/vrp/submit.json')
      @stub_VrpSubmit = stub_request(:post, uri_template).to_return(status: 417, body: File.new(File.expand_path('../../', __dir__) + '/fixtures/optimizer-wrapper/vrp-submit.json').read)

      uri_template = Addressable::Template.new('http://localhost:1791/0.1/vrp/jobs/{job_id}.json?api_key={api_key}')
      @stub_VrpFail = stub_request(:get, uri_template).to_return(status: 417, body: File.new(File.expand_path('../../', __dir__) + '/fixtures/optimizer-wrapper/vrp-fail.json').read)

      assert_raises VRPUnprocessableError do
        assert_match '/assert_vehicles_no_zero_duration/', optim.optimize(@planning, @planning.routes, optimize_minimal_time: 3)
      end
    ensure
      remove_request_stub(@stub_VrpSubmit)
      remove_request_stub(@stub_VrpFail)
    end
  end

  test 'simple progress call should return correct progression' do
    uri_template = Addressable::Template.new('http://localhost:1791/0.1/vrp/jobs/{job_id}.json?api_key={api_key}')

    # Simple progression
    progress = lambda{ |job_id, solution_data|
      if solution_data && solution_data[:status] != 'queued' && solution_data[:first_progression] && solution_data[:second_progression]
        assert_equal 100.0, solution_data[:first_progression]
        assert_equal 17.0, solution_data[:second_progression]
      end
    }
    vrp_simple_progression_file = File.new(Rails.root.join('test/fixtures/optimizer-wrapper/vrp-simple-progression.json')).read
    vrp_complete_file = File.new(Rails.root.join('test/fixtures/optimizer-wrapper/vrp-completed.json')).read

    # Multiple responses for repeated requests
    stub_vrp_job = stub_request(:get, uri_template).to_return({
      status: 200, body: vrp_simple_progression_file
    }, {
      status: 200, body: vrp_complete_file, headers: {content_type: 'json'}
    })

    @optim.optimize(@planning, @planning.routes, { optimize_time: 15000 }, &progress)
  ensure
    remove_request_stub(stub_vrp_job) if stub_vrp_job
  end

  test 'Max split progress call should return correct progression' do
    uri_template = Addressable::Template.new('http://localhost:1791/0.1/vrp/jobs/{job_id}.json?api_key={api_key}')

    # Max split progression
    progress = lambda{ |job_id, solution_data|
      if solution_data && solution_data[:status] != 'queued' && solution_data[:first_progression] && solution_data[:second_progression]
        assert_equal 75.0, solution_data[:first_progression]
        assert_equal 50.0, solution_data[:second_progression]
      end
    }
    vrp_max_split_progression_file = File.new(Rails.root.join('test/fixtures/optimizer-wrapper/vrp-max-split-progression.json')).read
    vrp_complete_file = File.new(Rails.root.join('test/fixtures/optimizer-wrapper/vrp-completed.json')).read

    # Multiple responses for repeated requests
    stub_vrp_job = stub_request(:get, uri_template).to_return({
      status: 200, body: vrp_max_split_progression_file
    }, {
      status: 200, body: vrp_complete_file, headers: {content_type: 'json'}
    })

    @optim.optimize(@planning, @planning.routes, { optimize_time: 30000 }, &progress)
  ensure
    remove_request_stub(stub_vrp_job) if stub_vrp_job
  end

  test 'dicho progress call should return correct progression' do
    uri_template = Addressable::Template.new('http://localhost:1791/0.1/vrp/jobs/{job_id}.json?api_key={api_key}')

    # Dicho progression
    progress = lambda{ |job_id, solution_data|
      if solution_data && solution_data[:status] != 'queued' && solution_data[:first_progression] && solution_data[:second_progression]
        assert_equal 100.0, solution_data[:first_progression]
        assert_equal 87.5, solution_data[:second_progression]
      end
    }
    vrp_dicho_progression_file = File.new(Rails.root.join('test/fixtures/optimizer-wrapper/vrp-dicho-progression.json')).read
    vrp_complete_file = File.new(Rails.root.join('test/fixtures/optimizer-wrapper/vrp-completed.json')).read

    # Multiple responses for repeated requests
    stub_vrp_job = stub_request(:get, uri_template).to_return({
      status: 200, body: vrp_dicho_progression_file
    }, {
      status: 200, body: vrp_complete_file, headers: {content_type: 'json'}
    })

    @optim.optimize(@planning, @planning.routes, { optimize_time: 30000 }, &progress)
  ensure
    remove_request_stub(stub_vrp_job) if stub_vrp_job
  end
end
