require 'test_helper'

require 'routers/osrm'

class Routers::OsrmTest < ActionController::TestCase
  setup do
    @osrm = Planner::Application.config.router_osrm
    @customer = customers(:customer_one)
  end

  test 'should compute matrix' do
    begin
      points = [[45.750569, 4.839445], [45.763661, 4.851408], [45.755932, 4.850413]]

      stubs_table = points.collect{ |point|
        # Workaround webmock + addressable using hash no working with duplicate params
        uri_template = Addressable::Template.new('http://localhost:5000/0.1/table?loc=' + point.join(','))
        stub_table = stub_request(:get, uri_template)
          .to_return(status: 200, body: File.new(File.expand_path('../../../web_mocks/', __FILE__) + '/osrm/table-1.json').read, headers: {})
      }

      matrix = @osrm.matrix(routers(:router_one).url_time, points)
      assert_equal 3, matrix.size
      assert_equal 3, matrix[0].size
    ensure
      stubs_table.each{ |stub_table| remove_request_stub(stub_table) }
    end
  end

  test 'should compute matrix on impassable' do
    begin
      points = [[46.634056, 2.547283], [42.161697, 9.138183]]

      stubs = points.collect{ |point|
        # Workaround webmock + addressable using hash no working with duplicate params
        uri_template = Addressable::Template.new('http://localhost:5000/0.1/viaroute?alt=false&loc=' + point.join(',') + '&output=json')
        stub_viaroute = stub_request(:get, uri_template).to_return(status: 200, body: File.new(File.expand_path('../../../web_mocks/', __FILE__) + '/osrm/viaroute-impassable.json').read)

        uri_template = Addressable::Template.new('http://localhost:5000/0.1/table?loc=' + point.join(','))
        stub_table = stub_request(:get, uri_template).to_return(status: 200, body: File.new(File.expand_path('../../../web_mocks/', __FILE__) + '/osrm/table-impassable.json').read)

        [stub_viaroute, stub_table]
      }

      impassable = @osrm.compute(routers(:router_one).url_time, *points.flatten)
      assert_not impassable[2] # no trace

      matrix = @osrm.matrix(routers(:router_one).url_time, points)
    ensure
      stubs.each{ |stub|
        remove_request_stub(stub[0])
        remove_request_stub(stub[1])
      }
    end
  end

  #  test 'should compute large matrix' do
  #    SIZE = 110
  #    prng = Random.new
  #    vector = SIZE.times.collect{ [prng.rand(48.811159..48.911218), prng.rand(2.270393..2.435532)] } # Some points in Paris
  #    #start = Time.now
  #    matrix = @osrm.matrix(routers(:router_one).url_time, vector)
  #    #finish = Time.now
  #    #puts finish - start
  #
  #    assert_equal SIZE, matrix.size
  #    assert_equal SIZE, matrix[0].size
  #  end
end
