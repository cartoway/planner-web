require 'test_helper'

require 'optim/optimizer_wrapper'

class OptimizerWrapperTest < ActionController::TestCase
  setup do
    @optim = OptimizerWrapper.new(ActiveSupport::Cache::NullStore.new, 'http://localhost:1791/0.1', 'demo')

    uri_template = Addressable::Template.new('http://localhost:1791/0.1/vrp/submit.json')
    @stub_VrpSubmit = stub_request(:post, uri_template).to_return(status: 200, body: File.new(File.expand_path('../../', __dir__) + '/fixtures/optimizer-wrapper/vrp-submit.json').read)

    uri_template = Addressable::Template.new('http://localhost:1791/0.1/vrp/jobs/{job_id}.json?api_key={api_key}')
    @stub_VrpJob = stub_request(:get, uri_template).to_return(status: 200, body: File.new(File.expand_path('../../', __dir__) + '/fixtures/optimizer-wrapper/vrp-job.json').read)

    @positions = [[1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 6]]
    @services = [
        {start1: nil, end1: nil, start2: nil, end2: nil, duration: 300.0, stop_id: 1, quantities: {}},
        {start1: nil, end1: nil, start2: nil, end2: nil, duration: 300.0, stop_id: 2, quantities: {}},
        {start1: 28800, end1: 36000, start2: nil, end2: nil, duration: 500.0, stop_id: 3},
        {start1: 0, end1: 7200, start2: nil, end2: nil, duration: 300.0, stop_id: 4},
    ]
    @vehicles = [
        {start1: 28800, end1: 36000, duration: 500.0, stop_id: 5, work_time: 0, stores: [:start], rests: []},
    ]
  end

  test 'should optimize' do
    begin
      p = [[1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 6]]
      t = [
        {start1: nil, end1: nil, start2: nil, end2: nil, duration: 300.0, stop_id: 1, quantities: {}},
        {start1: nil, end1: nil, start2: nil, end2: nil, duration: 300.0, stop_id: 2, quantities: {}},
        {start1: 28800, end1: 36000, start2: nil, end2: nil, duration: 500.0, stop_id: 3},
        {start1: 0, end1: 7200, start2: nil, end2: nil, duration: 300.0, stop_id: 4},
      ]
      r = [
        {start1: 28800, end1: 36000, duration: 500.0, stop_id: 5},
      ]

      assert_equal [[], [1, 2, 3, 4, 5]], @optim.optimize(p, t, [id: 1, stores: [:start, :stop], rests: r, router: routers(:router_one), capacities: {}], optimize_minimal_time: 3)

      assert_equal [[], [1, 2, 3, 4, 5]], @optim.optimize(p, t, [id: 1, stores: [:start], rests: r, router: routers(:router_one)], optimize_minimal_time: 3)

      assert_equal [[], [1, 2, 3, 4, 5]], @optim.optimize(p, t, [id: 1, stores: [], rests: r, router: routers(:router_one)], optimize_minimal_time: 3)
    ensure
      remove_request_stub(@stub_VrpJob)
      remove_request_stub(@stub_VrpSubmit)
    end
  end

  test 'should build relation' do
    begin
      p = [[1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 6]]
      t = [
        {start1: nil, end1: nil, start2: nil, end2: nil, duration: 300.0, stop_id: 1, quantities: {}},
        {start1: nil, end1: nil, start2: nil, end2: nil, duration: 300.0, stop_id: 2, quantities: {}},
        {start1: 28800, end1: 36000, start2: nil, end2: nil, duration: 500.0, stop_id: 3},
        {start1: 0, end1: 7200, start2: nil, end2: nil, duration: 300.0, stop_id: 4},
      ]
      r = [
        {start1: 28800, end1: 36000, duration: 500.0, stop_id: 5},
      ]
      rl = [
        { type: :order, linked_ids: [1, 2] }
      ]

      vrp = @optim.build_vrp(p, t, [id: 1, stores: [:start, :stop], rests: r, router: routers(:router_one), capacities: {}], optimize_minimal_time: 3, relations: rl)
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
        assert_match '/assert_vehicles_no_zero_duration/', optim.optimize(@positions, @services, @vehicles, optimize_minimal_time: 3)
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

    @optim.optimize(@positions, @services, @vehicles, optimize_time: 30000, &progress)
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

    @optim.optimize(@positions, @services, @vehicles, optimize_time: 30000, &progress)
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

    @optim.optimize(@positions, @services, @vehicles, optimize_time: 30000, &progress)
  ensure
    remove_request_stub(stub_vrp_job) if stub_vrp_job
  end
end
