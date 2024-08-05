require 'test_helper'

require 'optim/optimizer_wrapper'

class OptimizerWrapperTest < ActionController::TestCase
  setup do
    @optim = OptimizerWrapper.new(ActiveSupport::Cache::NullStore.new, 'http://localhost:1791/0.1', 'demo')

    uri_template = Addressable::Template.new('http://localhost:1791/0.1/vrp/submit.json')
    @stub_VrpSubmit = stub_request(:post, uri_template).to_return(status: 200, body: File.new(File.expand_path('../../', __dir__) + '/fixtures/optimizer-wrapper/vrp-submit.json').read)

    uri_template = Addressable::Template.new('http://localhost:1791/0.1/vrp/jobs/{job_id}.json?api_key={api_key}')
    @stub_VrpJob = stub_request(:get, uri_template).to_return(status: 200, body: File.new(File.expand_path('../../', __dir__) + '/fixtures/optimizer-wrapper/vrp-job.json').read)

    @planning = planning(:planning_one)
  end

  test 'should optimize' do
    begin
      routes = @planning.routes.select{ |route| route.vehicle_usage_id }
      assert_equal [[], [1, 2, 3, 4, 5]], @optim.optimize(@planning, routes, optimize_minimal_time: 3)
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

    @optim.optimize(@planning, @planning.routes, optimize_time: 30000, &progress)
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

    @optim.optimize(@planning, @planning.routes, optimize_time: 30000, &progress)
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

    @optim.optimize(@planning, @planning.routes, optimize_time: 30000, &progress)
  ensure
    remove_request_stub(stub_vrp_job) if stub_vrp_job
  end
end
