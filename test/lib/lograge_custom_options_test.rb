# frozen_string_literal: true

require 'test_helper'

class LogrageCustomOptionsTest < ActiveSupport::TestCase
  test 'action cable disconnect without params does not raise' do
    event = ActiveSupport::Notifications::Event.new(
      'disconnect.action_cable',
      Time.current,
      Time.current,
      '1',
      { channel_class: 'Turbo::StreamsChannel' }
    )

    options = Rails.application.config.lograge.custom_options.call(event)
    assert options.key?(:time)
    assert_nil options[:params]
  end
end
