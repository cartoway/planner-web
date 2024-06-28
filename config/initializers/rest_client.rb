class RestClient::Request
  @@duration = {}

  class << self
    def execute_with_capture_duration(args, &block)
      started = Time.now
      res = execute_without_capture_duration(args, &block)
      @@duration[Thread.current.object_id] = (@@duration[Thread.current.object_id] || 0) + (Time.now - started)
      return res
    end

    def start_capture_duration
      @@duration[Thread.current.object_id] = 0
    end

    def end_capture_duration
      @@duration[Thread.current.object_id]
    end

    alias_method :execute_without_capture_duration, :execute
    alias_method :execute, :execute_with_capture_duration
  end
end

RestClient.proxy = ENV['http_proxy']
