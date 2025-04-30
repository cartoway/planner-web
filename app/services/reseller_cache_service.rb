class ResellerCacheService
  CACHE_PREFIX = 'reseller:'.freeze
  CACHE_EXPIRATION = 1.hour

  def self.fetch(host)
    Rails.cache.fetch(cache_key(host), expires_in: CACHE_EXPIRATION) do
      Reseller.where(host: host).first || Reseller.first
    end
  end

  def self.invalidate(host)
    Rails.cache.delete(cache_key(host))
  end

  def self.invalidate_all
    Reseller.find_each do |reseller|
      invalidate(reseller.host)
    end
  end

  def self.cache_key(host)
    "#{CACHE_PREFIX}#{host}"
  end
end
