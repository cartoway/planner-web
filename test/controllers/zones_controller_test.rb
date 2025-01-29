require 'test_helper'

class ZonesControllerTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @zoning = zonings(:zoning_one)
    sign_in users(:user_one)
  end

  test 'should get show in excel' do
    get :show, params: { id: @zoning.zones.first, zoning_id: @zoning.id, format: :excel, locale: 'fr' }
    assert_response :success
    assert_equal "b;destination_one;Rue des Lilas;MyString;33200;Bordeau;;49.1857;-0.3735;;;;MyString;MyString;\"\";zone_one;\"\";b;00:05:33;10:00;11:00;;;4;;tag1;neutre\r".encode("iso-8859-1"), response.body.split("\n").find{ |l| l.start_with? 'b;destination_one' }
  end
end
