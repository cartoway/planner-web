# frozen_string_literal: true

require 'test_helper'

class SopacBroker::MessageHandlers::HubTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
    @store = ActiveSupport::Cache::MemoryStore.new
    @cache = SopacBroker::Cache.new(@customer.id, store: @store)
    SopacBroker::Cache.stubs(:new).returns(@cache)
  end

  test 'stores hub payload from JSON' do
    body = { id: '0000181B', status: 'online', label: 'Hub 1' }.to_json

    SopacBroker::MessageHandlers::Hub.call(@customer.id, body)

    stored = @cache.read_hub('0000181B')
    assert_equal 'online', stored['status']
    assert_equal 'Hub 1', stored['label']
  end

  test 'ignores payload without hub id' do
    SopacBroker::MessageHandlers::Hub.call(@customer.id, { status: 'online' }.to_json)

    assert_nil @cache.read_hub('0000181B')
  end
end
