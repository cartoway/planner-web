require 'test_helper'

class ResellerTest < ActiveSupport::TestCase
  setup do
    @reseller = resellers(:reseller_one)
  end

  test 'should call invalidate cache after update' do
    ResellerCacheService.expects(:invalidate).once.with(@reseller.host)
    @reseller.update!(name: 'New Name')
  end
end
