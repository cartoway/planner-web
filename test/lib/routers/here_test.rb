require 'test_helper'

require 'routers/here'

class Routers::HereTest < ActionController::TestCase
  setup do
    @here = Planner::Application.config.router_here
    @customer = customers(:customer_one)
  end

  test 'should compute route' do
    begin
      uri_template = Addressable::Template.new('https://route.api.here.com/routing/{api_version}/calculateroute.json?alternatives=0&app_code={app_code}&app_id={app_id}&mode=fastest%3Btruck%3Btraffic:disabled&representation=display&resolution=1&routeAttributes=summary,shape&truckType=truck&waypoint0=geo!45.750569,4.839445&waypoint1=geo!45.763661,4.851408')
      stub = stub_request(:get, uri_template).to_return(File.new(File.expand_path('../../../web_mocks/', __FILE__) + '/route.api.here.com/calculateroute.json').read)

      trace = @here.compute(45.750569, 4.839445, 45.763661, 4.851408)
      assert trace
    ensure
      remove_request_stub(stub)
    end
  end

  test 'should compute matrix' do
    begin
      uri_template = Addressable::Template.new('https://matrix.route.api.here.com/routing/{api_version}/calculatematrix.json?app_code={app_code}&app_id={app_id}&destination0=45.75057,4.83945&destination1=45.76366,4.85141&destination2=45.75593,4.85041&mode=fastest%3Btruck%3Btraffic:disabled&start0=45.75057,4.83945&start1=45.76366,4.85141&start2=45.75593,4.85041&summaryAttributes=traveltime&truckType=truck')
      stub = stub_request(:get, uri_template).to_return(File.new(File.expand_path('../../../web_mocks/', __FILE__) + '/route.api.here.com/calculatematrix.json').read)

      vector = [[45.750569, 4.839445], [45.763661, 4.851408], [45.755932, 4.850413]]
      matrix = @here.matrix(vector, vector, :time)
      assert_equal 3, matrix.size
      assert_equal 3, matrix[0].size
    ensure
      remove_request_stub(stub)
    end
  end

  test 'should compute rectangular matrix' do
    begin
      uri_template = Addressable::Template.new('https://matrix.route.api.here.com/routing/{api_version}/calculatematrix.json?app_code={app_code}&app_id={app_id}&destination0=45.75057,4.83945&destination1=45.76366,4.85141&destination2=45.75593,4.85041&mode=fastest%3Btruck%3Btraffic:disabled&start0=47.3174,5.0336&summaryAttributes=traveltime&truckType=truck')
      stub = stub_request(:get, uri_template).to_return(File.new(File.expand_path('../../../web_mocks/', __FILE__) + '/route.api.here.com/calculate_rectangular_matrix.json').read)

      row = [[47.3174, 5.0336]]
      column = [[45.750569, 4.839445], [45.763661, 4.851408], [45.755932, 4.850413]]
      matrix = @here.matrix(row, column, :time)
      assert_equal 1, matrix.size
      assert_equal 3, matrix[0].size
    ensure
      remove_request_stub(stub)
    end
  end

  #  test 'should compute large matrix' do
  #    SIZE = 100
  #    prng = Random.new
  #    vector = SIZE.times.collect{ [prng.rand(48.811159..48.911218), prng.rand(2.270393..2.435532)] } # Some points in Paris
  #    #start = Time.now
  #    matrix = @here.matrix(vector, vector)
  #    #finish = Time.now
  #    #puts finish - start
  #
  #    assert_equal SIZE, matrix.size
  #    assert_equal SIZE, matrix[0].size
  #  end
end
