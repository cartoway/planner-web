require 'test_helper'

class LinkBackTest < ActionController::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    request.host = @reseller.host
    @destination = destinations(:destination_one)
    sign_in users(:user_one)
    @controller = DestinationsController.new

    @previous_url = 'http://test.host/previous'
    request.headers['Turbolinks-Referrer'] = @previous_url
  end

  test 'should save link_back when back parameter is present' do
    get :edit, params: { id: @destination, back: true }

    assert_equal URI.parse(@previous_url).path, session[:link_back]
  end

  test 'should not save link_back when back parameter is not present' do
    get :edit, params: { id: @destination }

    assert_nil session[:link_back]
  end

  test 'should redirect to link_back after successful update' do
    get :edit, params: { id: @destination, back: true }

    assert_equal URI.parse(@previous_url).path, session[:link_back]

    patch :update, params: {
      id: @destination,
      destination: {
        name: 'Updated Destination',
        city: 'Updated City'
      }
    }

    assert_redirected_to URI.parse(@previous_url).path
    assert_nil session[:link_back]
  end

  test 'should redirect to default path when no link_back in session' do
    request.headers['Turbolinks-Referrer'] = nil
    get :edit, params: { id: @destination, back: true }

    patch :update, params: {
      id: @destination,
      destination: {
        name: 'Updated Destination',
        city: 'Updated City'
      }
    }

    assert_redirected_to edit_destination_path(@destination)
  end

  test 'should handle referer with query parameters' do
    request.headers['Turbolinks-Referrer'] = 'http://test.host/plannings/1/edit?with_stops=true'

    get :edit, params: { id: @destination, back: true }

    assert_equal '/plannings/1/edit', session[:link_back]
  end

  test 'should handle referer with fragment but not redirect to it' do
    # TODO: It might be interesting to link back to it
    # It should be handled client side, as not sending it is an html specification
    request.headers['Turbolinks-Referrer'] = 'http://test.host/plannings/1/edit#collapseVisit123'

    get :edit, params: { id: @destination, back: true }

    assert_equal '/plannings/1/edit', session[:link_back]
  end

  test 'should handle missing referer gracefully' do
    request.headers['Turbolinks-Referrer'] = nil
    get :edit, params: { id: @destination, back: true }

    assert_nil session[:link_back]
  end
end
