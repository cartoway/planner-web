require 'test_helper'

class ImportExportCustomerTest < ActionController::TestCase

  test 'should export customer with all its relations' do
    customer = customers(:customer_one)
    export = ImportExportCustomer.export(customer)

    #assert that new customer will not be a duplication for this test
    customer.destroy

    assert_kind_of String, export

    new_customer = Marshal.load(export)
    assert_kind_of Customer, new_customer

    refute_empty new_customer.stores
    refute_empty new_customer.deliverable_units
    refute_empty new_customer.vehicles
    refute_empty new_customer.vehicles.first.vehicle_usages
    refute_empty new_customer.vehicle_usage_sets
    refute_empty new_customer.tags
    refute_empty new_customer.zonings
    refute_empty new_customer.zonings.first.zones
    refute_empty new_customer.destinations
    refute_empty new_customer.destinations.first.visits
    refute_empty new_customer.plannings
    refute_empty new_customer.plannings.first.routes
    refute_empty new_customer.plannings.first.routes.first.stops
    refute_empty new_customer.users
  end

  test 'should import customer from file with all its relations' do
    customer = customers(:customer_one)
    customer_data = ImportExportCustomer.export(customer)
    customer_data_file = Tempfile.new(['customer_dump', '.bin'])
    customer_data_file.binmode
    customer_data_file.write(customer_data)
    customer_data_file.rewind
    profile_id = profiles(:profile_two).id
    router_id = routers(:router_two).id
    layer_id = layers(:layer_two).id

    assert_difference "Customer.count", 1 do
      assert_difference "Store.count", 4 do
        assert_difference "DeliverableUnit.count", 2 do
          assert_difference "Vehicle.count", 2 do
            assert_difference "VehicleUsage.count", 4 do
              assert_difference "VehicleUsageSet.count", 2 do
                assert_difference "Tag.count", 2 do
                  assert_difference "Zoning.count", 2 do
                    assert_difference "Zone.count", 3 do
                      assert_difference "Destination.count", 4 do
                        assert_difference "Visit.count", 4 do
                          assert_difference "Planning.count", 2 do
                            assert_difference "Route.count", 6 do
                              assert_difference "Stop.count", 8 do
                                assert_difference "User.count", 3 do
                                  c = ImportExportCustomer.import(customer_data_file, { profile_id: profile_id, router_id: router_id, layer_id: layer_id})
                                  assert_kind_of Customer, c
                                  assert_equal profile_id, c.profile_id
                                  assert_equal router_id, c.router_id
                                  assert_equal layer_id, c.users.first.layer_id
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  ensure
    customer_data_file.close! if customer_data_file
  end
end
