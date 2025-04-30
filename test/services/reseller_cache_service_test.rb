require 'test_helper'

class ResellerCacheServiceTest < ActiveSupport::TestCase
  setup do
    @reseller = resellers(:reseller_one)
    @cache = mock
    Rails.cache = @cache
  end

  teardown do
    Rails.cache = ActiveSupport::Cache::NullStore.new
  end

  test 'should fetch reseller from cache' do
    cache_key = ResellerCacheService.send(:cache_key, @reseller.host)

    # Simulate cache miss and database hit
    @cache.expects(:fetch).with(cache_key, expires_in: ResellerCacheService::CACHE_EXPIRATION).yields.returns(@reseller)
    Reseller.expects(:where).once.with(host: @reseller.host).returns([@reseller])

    reseller = ResellerCacheService.fetch(@reseller.host)
    assert_equal @reseller, reseller
  end

  test 'should use cached value when available' do
    cache_key = ResellerCacheService.send(:cache_key, @reseller.host)

    # Simulate cache hit
    @cache.expects(:fetch).with(cache_key, expires_in: ResellerCacheService::CACHE_EXPIRATION).returns(@reseller)
    Reseller.expects(:where).never

    reseller = ResellerCacheService.fetch(@reseller.host)
    assert_equal @reseller, reseller
  end

  test 'should invalidate cache' do
    cache_key = ResellerCacheService.send(:cache_key, @reseller.host)
    @cache.expects(:delete).once.with(cache_key)
    ResellerCacheService.invalidate(@reseller.host)
  end

  test 'should invalidate all caches' do
    Reseller.find_each do |reseller|
      cache_key = ResellerCacheService.send(:cache_key, reseller.host)
      @cache.expects(:delete).once.with(cache_key)
    end

    ResellerCacheService.invalidate_all
  end
end
