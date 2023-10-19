require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase

  test 'should return an url formated when reseller has behavior url' do
    reseller = resellers(:reseller_one)
    reseller.audience_url = 'https://analytics.cartoroute.com/public/dashboard/{ID}'

    url = analytic_url_for(reseller, :audience_url)

    assert url
    assert_equal "https://analytics.cartoroute.com/public/dashboard/#{reseller.id}", url
  end
end
