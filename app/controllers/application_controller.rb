# Copyright © Mapotempo, 2013-2016
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class ApplicationController < ActionController::Base
  include LockingUtils

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # Handle exceptions
  rescue_from StandardError, with: :server_error if Planner::Application.config.raise_on_standard_error
  rescue_from ActionController::InvalidAuthenticityToken, with: :server_error
  rescue_from ActiveRecord::RecordNotFound, with: :not_found_error
  rescue_from AbstractController::ActionNotFound, with: :not_found_error
  rescue_from ActiveRecord::StaleObjectError, with: :database_error
  rescue_from PG::TRDeadlockDetected, with: :database_error
  rescue_from ActiveRecord::StatementInvalid, with: :database_error
  rescue_from PG::TRSerializationFailure, with: :database_error
  rescue_from Exceptions::JobInProgressError, with: :job_in_progress
  rescue_from Exceptions::StopIndexError, with: :stop_index_error
  rescue_from Exceptions::OutdatedRequestError, with: :conflict_error

  layout :layout_by_resource

  # saves the location before loading each page so we can return to the right page.
  before_action :set_reseller
  before_action :api_key?, :load_vehicles
  before_action :driver_token?
  before_action :set_driver
  before_action :set_locale
  before_action :customer_payment_period, if: :current_user
  around_action :set_time_zone, if: :current_user
  around_action :track_sub_api_time

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, alert: exception.message
  end

  def api_key?
    if params['api_key']
      if (user = User.find_by(api_key: params['api_key']))
        warden.set_user(user, run_callbacks: false)
      else
        redirect_to new_user_session_path, alert: t('web.key_not_found')
      end
    end
  end

  def driver_token?
    if params['driver_token']
      if (vehicle = Vehicle.find_by(driver_token: params['driver_token']))
        @current_vehicle = vehicle
        session[:current_driver_id] = vehicle.id
      else
        redirect_to new_user_session_path, alert: t('web.key_not_found')
      end
    end
  end

  def set_driver
    if session[:current_driver_id]
      @current_vehicle ||= Vehicle.find(session[:current_driver_id])
    end
  end

  def load_vehicles
    if current_user && !current_user.admin?
      @vehicle_usage_sets = current_user.customer.vehicle_usage_sets.includes([:vehicle_usages, {vehicle_usages: [:vehicle]}])
    end
  end

  def append_info_to_payload(payload)
    super
    # More info for Lograge
    payload[:customer_id] = current_user && current_user.customer && current_user.customer.id
    if @sub_api_time
      payload[:sub_api_time] = @sub_api_time[Thread.current.object_id]
      @sub_api_time[Thread.current.object_id] = nil
    end
  end

  protected

  def set_time_zone(&block)
    Time.use_zone(current_user.time_zone, &block)
  end

  def set_locale
    I18n.locale = http_accept_language.compatible_language_from(I18n.available_locales) || I18n.default_locale
  end

  def set_reseller
    @reseller = Reseller.where(host: "#{request.host}#{request.port && ":#{request.port}"}").first || request.env['reseller']
  end

  def track_sub_api_time(&block)
    RestClient::Request.start_capture_duration
    ret = block.call
    @sub_api_time ||= {}
    @sub_api_time[Thread.current.object_id] = RestClient::Request.end_capture_duration * 1000
    ret
  end

  def devise_parameter_sanitizer
    if resource_class == User
      UserParameterSanitizer.new(User, :user, params)
    else
      super
    end
  end

  def layout_by_resource
    if devise_controller?
      'registration'
    else
      'application'
    end
  end

  def customer_payment_period
    if current_user.customer
      customer = current_user.customer
      @unsubscribed = customer.end_subscription && Time.now >= customer.end_subscription
      if @unsubscribed
        flash.now[:error] = I18n.t('all.subscribe.expiration_date_over', date: I18n.l((customer.end_subscription - 1.second), format: :long), reseller: @reseller&.name)
      end
    end
  end

  def js_redirect_to(path, flash_type = nil, flash_message = nil)
    if flash_type
      flash[flash_type] = flash_message
    end

    render js: %(window.location.href='#{path}') and return
  end

  def authenticate_user!(options = {})
    if user_signed_in?
      super(options)
    else
      self.response_body = nil
      respond_to do |format|
        format.js do
          flash[:alert] = I18n.t('devise.failure.unauthenticated')
          js_redirect_to(root_path)
        end
        format.html do
          redirect_to root_path, notice: I18n.t('devise.failure.unauthenticated')
        end
        format.json do
          flash.now[:alert] = I18n.t('devise.failure.unauthenticated')
          render json:   { error: I18n.t('devise.failure.unauthenticated') }.to_json,
                 status: :forbidden
        end
      end
    end
  end

  def authenticate_driver!
    if vehicle_signed_in?
      nil
    else
      self.response_body = nil
      respond_to do |format|
        format.js do
          flash[:alert] = I18n.t('devise.failure.unauthenticated')
          js_redirect_to(root_path)
        end
        format.html do
          redirect_to root_path, notice: I18n.t('devise.failure.unauthenticated')
        end
        format.json do
          flash.now[:alert] = I18n.t('devise.failure.unauthenticated')
          render json:   { error: I18n.t('devise.failure.unauthenticated') }.to_json,
                 status: :forbidden
        end
      end
    end
  end

  def over_max_limit
    yield
  rescue Exceptions::OverMaxLimitError
    respond_to do |format|
      flash.now[:alert] = I18n.t("activerecord.errors.models.customer.attributes.#{controller_name}.over_max_limit")
      if action_name == 'create'
        format.html { render action: 'new' }
      elsif action_name.start_with? 'upload'
        format.html { render action: 'import' }
      else
        format.html { render action: 'index' }
      end
    end
  end

  def not_found_error(exception)
    log_error(exception, :error)

    respond_to do |format|
      flash[:error] = [I18n.t('errors.management.status.title.404')]
      format.js { render partial: 'shared/error_messages.js.erb', status: :not_found }
      format.html { render 'errors/show', layout: 'full_page', locals: { status: 404 }, status: 404 }
      format.json { render json: { type: 'not_found', error: I18n.t('errors.management.status.title.404') }, status: 404 }
      format.all { render body: nil, status: :not_found }
    end
  end

  def conflict_error(exception)
    log_error(exception)

    respond_to do |format|
      flash[:error] = [I18n.t('errors.management.status.title.409')]
      format.js { render partial: 'shared/error_messages.js.erb', status: :conflict }
      format.html { render 'errors/show', layout: 'full_page', locals: { status: 409 }, status: 409 }
      format.json { render json: { type: 'conflict', error: I18n.t('errors.management.status.title.409') }, status: 409 }
      format.all { render body: nil, status: :conflict }
    end
  end

  def server_error(exception)
    log_error(exception, :error)

    respond_to do |format|
      flash[:error] = [I18n.t('errors.management.description')]
      format.js { render partial: 'shared/error_messages.js.erb', status: :internal_server_error }
      format.html { render 'errors/show', layout: 'full_page', locals: { status: 500 }, status: 500 }
      format.json { render json: { type: 'server', error: I18n.t('errors.management.description') }, status: 500 }
      format.all { render body: nil, status: :internal_server_error }
    end
  end

  def database_error(exception)
    log_error(exception, :warn)

    errors = [I18n.t('errors.database.default')]
    types = ['database']
    case exception
    when ActiveRecord::StatementInvalid
      errors << I18n.t('errors.database.invalid_statement')
      types << 'invalid_statement'
    when PG::TRDeadlockDetected, ActiveRecord::StaleObjectError, PG::TRSerializationFailure
      errors << I18n.t('errors.database.deadlock')
      types << 'deadlock'
    end

    respond_to do |format|
      flash[:error] = errors
      format.js { render partial: 'shared/error_messages.js.erb', status: :unprocessable_entity }
      format.html { render 'errors/show', layout: 'full_page', locals: { status: 422 }, status: 422 }
      format.json { render json: { type: types.join('/'), error: errors.join(' ') }, status: :unprocessable_entity }
    end
  end

  def job_in_progress(exception)
    log_error(exception, :warn)

    respond_to do |format|
      flash[:error] = [I18n.t('errors.planning.job_in_progress')]
      format.js { render partial: 'shared/error_messages.js.erb', status: :unprocessable_entity }
      format.json { render json: { type: 'job_in_progress', error: I18n.t('errors.planning.job_in_progress') }, status: :unprocessable_entity }
    end
  end

  def stop_index_error(exception)
    log_error(exception)
    respond_to do |format|
      flash[:error] = [exception.to_s]
      format.js { render partial: 'shared/error_messages.js.erb', status: :unprocessable_entity }
      format.html { render 'errors/show', layout: 'full_page', locals: { status: 422 }, status: 422 }
      format.json { render json: { type: 'stop_index', error: exception.to_s }, status: :unprocessable_entity }
    end
  end

  def format_filename(filename)
    filename
  end

  def parse_router_options(params)
    params['router_options'].each { |key, value| # Unsage navigation
      if value == 'true' || value == 'false'
        params['router_options'][key] = ValueToBoolean.value_to_boolean(value)
      elsif (value.respond_to?(:to_f) && value.to_f != 0.0)
        params['router_options'][key] = value.to_f
      end
    }
  end

  private

  def log_error(exception, level = :fatal)
    return if Rails.env.test?

    Rails.logger.send(level, "#{exception.class} : #{exception}")
    Rails.logger.send(level, exception.backtrace.join("\n"))
  end
end
