RailsPerformance.setup do |config|
  config.redis = Redis.new(url: "redis://redis-cache:6379/1")
  config.duration = 4.hours
  config.enabled = !Rails.env.test?

  config.ignored_endpoints = ['Devise::SessionsController#new']
  config.ignored_paths = ['/rails/performance', '/up']
end

# Monkey patch, to log in JSON format
if ENV['LOG_FORMAT'] == 'json'
  module RailsPerformance
    module Extensions
      class ResourceMonitor
        def store_data(data)
          ::Rails.logger.info("RailsPerformance", server: server_id, context: context, role: role, data: data)

          now = RailsPerformance::Utils.time
          now = now.change(sec: 0, usec: 0)
          RailsPerformance::Models::ResourceRecord.new(
            server: server_id,
            context: context,
            role: role,
            datetime: now.strftime(RailsPerformance::FORMAT),
            datetimei: now.to_i,
            json: data
          ).save
        end
      end
    end
  end
end
