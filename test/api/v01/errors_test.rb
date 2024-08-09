require 'test_helper'

class V01::ErrorTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def app
    Rails.application
  end

  setup do
    @customer = customers(:customer_one)
  end

  def api(part = nil, param = {}, format = 'json')
    part = part ? '/' + part.to_s : ''
    "/api/0.1/customers#{part}.#{format}?api_key=testkey1&" + param.collect{ |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  def database_error_assertions(message)
    (assert_equal 409, last_response.status) &&
      (assert_kind_of Hash, JSON.parse(last_response.body)) &&
      (assert_equal message, JSON.parse(last_response.body)['message'])
  end

  test 'should return a 404 error in JSON format for route not found' do
    get api('not_found', {}, 'json')
    assert_equal 404, last_response.status, 'Bad response for JSON request: ' + last_response.body
    assert_equal 'application/json; charset=UTF-8', last_response.content_type, 'Bad content type for request: ' + last_response.body
  end

  test 'should rescue database error' do
    message = "#{I18n.t('errors.database.default')} #{I18n.t('errors.database.invalid_statement')}"
    Customer.stub_any_instance(:assign_attributes, ->(*_a) { raise ActiveRecord::StatementInvalid.new(self) }) do
      put api(@customer.id), ref: 'ref-abcd'
      assert database_error_assertions(message)
    end

    message = "#{I18n.t('errors.database.default')} #{I18n.t('errors.database.deadlock')}"
    Customer.stub_any_instance(:assign_attributes, ->(*_a) { raise ActiveRecord::StaleObjectError.new(self) }) do
      put api(@customer.id), ref: 'ref-abcd'
      assert database_error_assertions(message)
    end

    Customer.stub_any_instance(:assign_attributes, ->(*_a) { raise PG::TRDeadlockDetected.new }) do
      put api(@customer.id), ref: 'ref-abcd'
      assert database_error_assertions(message)
    end

    Customer.stub_any_instance(:assign_attributes, ->(*_a) { raise PG::TRSerializationFailure.new }) do
      put api(@customer.id), ref: 'ref-abcd'
      assert database_error_assertions(message)
    end
  end
end
