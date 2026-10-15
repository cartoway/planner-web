require 'test_helper'

class ServiceWorkerPhotosTest < ActiveSupport::TestCase
  test 'service worker and mobile client queue photos for background sync' do
    sw = File.read(Rails.root.join('public/service-worker.js'))
    stops = File.read(Rails.root.join('app/assets/javascripts/stops.js'))
    mobile = File.read(Rails.root.join('app/javascript/controllers/mobile_controller.js'))

    assert_includes sw, "case 'sync-photos'"
    assert_includes sw, "case 'STORE_PHOTO'"
    assert_includes sw, 'function syncPhotos'
    assert_includes stops, 'queuePhotoUpload'
    assert_includes stops, 'planner-mobile-photos'
    assert_includes stops, 'xhr.status === 404'
    assert_includes stops, 'compressImages'
    assert_includes mobile, "this.registerSync('sync-photos')"
    assert_includes mobile, "from 'lib/compress_image'"
    assert_includes mobile, 'compressImages'
    assert_includes mobile, 'resolveStopPhotosPanel'
    assert_includes mobile, 'syncModalAfterPhotoChange'
    assert_includes mobile, 'photosWithinLimit'
    assert_includes mobile, 'response.status >= 400 && response.status < 500'
    assert_includes stops, 'xhr.status >= 400 && xhr.status < 500'
    assert_includes sw, "item.method === 'DELETE' && response.status === 404"
    assert_includes sw, "notifyClients('PHOTO_REJECTED'"
    assert_includes mobile, "type === 'PHOTO_REJECTED'"
    assert_includes mobile, 'deleteQueuedPhoto'
    assert_includes mobile, 'showFailed('
    refute_includes mobile, 'window.alert'
    assert_includes mobile, 'stop-photo-pending-spinner'
    assert_includes mobile, 'afterPaint'
    assert_includes mobile, 'updatePendingPhotos'
    assert_includes stops, 'updatePendingPhotos'
    assert_includes stops, 'photoUploadErrorMessage'
    assert_includes stops, 'showMobileFailed'
    assert_includes stops, 'stop-photo-pending-spinner'
    refute_includes stops, 'window.alert'
  end
end
