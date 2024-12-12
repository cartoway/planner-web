RailsPerformance.setup do |config|
  config.redis = Redis.new(url: "redis://redis-cache:6379/1")
  config.duration = 4.hours
  config.enabled = !Rails.env.test?
end
