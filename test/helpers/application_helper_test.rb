require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase

  test 'should return an url formated when reseller has behavior url' do
    reseller = resellers(:reseller_one)
    reseller.audience_url = 'https://analytics.cartoway.com/public/dashboard/{ID}'

    url = analytic_url_for(reseller, :audience_url)

    assert url
    assert_equal "https://analytics.cartoway.com/public/dashboard/#{reseller.id}", url
  end

  test 'round_time_to_nearest_quarter rounds to 00' do
    t = Time.zone.parse('2024-05-21 10:07:00')
    assert_equal Time.zone.parse('2024-05-21 10:00:00'), round_time_to_nearest_quarter(t)
  end

  test 'round_time_to_nearest_quarter rounds to 15' do
    t = Time.zone.parse('2024-05-21 10:08:00')
    assert_equal Time.zone.parse('2024-05-21 10:15:00'), round_time_to_nearest_quarter(t)

    t = Time.zone.parse('2024-05-21 10:22:00')
    assert_equal Time.zone.parse('2024-05-21 10:15:00'), round_time_to_nearest_quarter(t)
  end

  test 'round_time_to_nearest_quarter rounds to 30' do
    t = Time.zone.parse('2024-05-21 10:23:00')
    assert_equal Time.zone.parse('2024-05-21 10:30:00'), round_time_to_nearest_quarter(t)

    t = Time.zone.parse('2024-05-21 10:37:00')
    assert_equal Time.zone.parse('2024-05-21 10:30:00'), round_time_to_nearest_quarter(t)
  end

  test 'round_time_to_nearest_quarter rounds to 45' do
    t = Time.zone.parse('2024-05-21 10:38:00')
    assert_equal Time.zone.parse('2024-05-21 10:45:00'), round_time_to_nearest_quarter(t)

    t = Time.zone.parse('2024-05-21 10:52:00')
    assert_equal Time.zone.parse('2024-05-21 10:45:00'), round_time_to_nearest_quarter(t)
  end

  test 'round_time_to_nearest_quarter rounds to the next hour if close to 60' do
    t = Time.zone.parse('2024-05-21 10:53:00')
    assert_equal Time.zone.parse('2024-05-21 11:00:00'), round_time_to_nearest_quarter(t)
  end
end
