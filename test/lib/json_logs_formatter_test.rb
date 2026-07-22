# frozen_string_literal: true

require 'test_helper'

class JsonLogsFormatterTest < ActiveSupport::TestCase
  setup do
    @logger = StructuredLog.new(nil)
    @previous_log_format = ENV.fetch('LOG_FORMAT', nil)
    ENV['LOG_FORMAT'] = 'json'
  end

  teardown do
    if @previous_log_format.nil?
      ENV.delete('LOG_FORMAT')
    else
      ENV['LOG_FORMAT'] = @previous_log_format
    end
  end

  test 'merge accepts exception objects without raising' do
    error = NoMethodError.new("undefined method `read' for nil:NilClass")
    payload = @logger.merge(error)

    assert_equal error.to_s, JSON.parse(payload)['message']
  end
end
