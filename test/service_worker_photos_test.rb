require 'test_helper'

class ServiceWorkerPhotosTest < ActiveSupport::TestCase
  test 'service worker and mobile client queue photos for background sync' do
    sw = File.read(Rails.root.join('public/service-worker.js'))
    stops = File.read(Rails.root.join('app/assets/javascripts/stops.js'))
    mobile = File.read(Rails.root.join('app/assets/javascripts/mobile.js'))

    assert_includes sw, "case 'sync-photos'"
    assert_includes sw, "case 'STORE_PHOTO'"
    assert_includes sw, 'function syncPhotos'
    assert_includes stops, 'queuePhotoUpload'
    assert_includes stops, 'planner-mobile-photos'
    assert_includes mobile, "registration.sync.register('sync-photos')"
  end
end
