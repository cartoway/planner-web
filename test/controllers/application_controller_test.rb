require 'test_helper'

class ApplicationControllerTest < ActionController::TestCase
  ApplicationController.class_eval do
    def index
      render nothing: true
    end
  end

  Rails.application.routes.disable_clear_and_finalize = true

  Rails.application.routes.draw do
    get 'index' => 'application#index'
  end

  test 'should set user from api key without updating sign in at' do
    users(:user_one).update(current_sign_in_at: Time.new(2000), last_sign_in_at: Time.new(2000))

    get :index, params: { api_key: 'testkey1' }
    assert_equal [Time.new(2000)], users(:user_one).reload.attributes.slice('current_sign_in_at', 'last_sign_in_at').values.uniq
  end

  test 'should return an error with flash[:error]' do
    users(:user_one).customer.update! end_subscription: (Time.now - 30.days)
    sign_in users(:user_one)
    get :index
    assert_not_nil flash.now[:error]
  end

  test 'should rescue database error' do
    message = "#{I18n.t('errors.database.default')} #{I18n.t('errors.database.deadlock')}"
    ApplicationController.stub_any_instance(:api_key?, lambda { |*a| raise ActiveRecord::StaleObjectError.new(self, nil) }) do
      get :index, params: { format: :json }
      assert_equal message, JSON.parse(response.body)['error']
      assert_response :unprocessable_entity
    end

    ApplicationController.stub_any_instance(:api_key?, lambda { |*a| raise PG::TRDeadlockDetected.new }) do
      get :index, params: { format: :json, only_path: true }
      assert_equal message, JSON.parse(response.body)['error']
      assert_response :unprocessable_entity
    end

    ApplicationController.stub_any_instance(:api_key?, lambda { |*a| raise ActiveRecord::StatementInvalid.new(self) }) do
      get :index, params: { format: :json }
      assert_equal "#{I18n.t('errors.database.default')} #{I18n.t('errors.database.invalid_statement')}", JSON.parse(response.body)['error']
      assert_response :unprocessable_entity
    end

    ApplicationController.stub_any_instance(:api_key?, lambda { |*a| raise PG::TRSerializationFailure.new }) do
      get :index, params: { format: :json }
      assert_equal message, JSON.parse(response.body)['error']
      assert_response :unprocessable_entity
    end
  end

  test 'should rescue server error' do
      ApplicationController.stub_any_instance(:api_key?, lambda { |*a| raise ActionController::InvalidAuthenticityToken.new }) do
        get :index, params: { format: :json }
        assert_response :internal_server_error
      end
  end
end
