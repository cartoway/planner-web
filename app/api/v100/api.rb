require 'exceptions'

class V100::Api < Grape::API
  helpers do
    def session
      env[Rack::RACK_SESSION]
    end

    def warden
      env && env['warden']
    end

    def current_customer(customer_id = nil)
      api_key = headers['Api-Key'] || params[:api_key]
      @current_user ||= api_key && User.find_by(api_key: api_key)
      @current_user ||= warden.authenticated? && warden.user
      @current_customer ||= @current_user && (@current_user.admin? && customer_id ? @current_user.reseller.customers.find(customer_id) : @current_user.customer)
    end

    def authenticate!
      error!(V100::Status.code_response(:code_401), 401) unless env
      current_customer
      error!(V100::Status.code_response(:code_401), 401) unless @current_user
      error!(V100::Status.code_response(:code_402, after: "Subscription expired (#{@current_customer.end_subscription.to_s}) - Contact your reseller."), 402) if @current_customer && @current_customer.end_subscription && @current_customer.end_subscription < Time.now
    end

    def authorize!
    end

    def set_time_zone
      Time.zone = @current_user.time_zone
    end

    def set_locale
      I18n.locale = env.http_accept_language.compatible_language_from(I18n.available_locales.map(&:to_s)) || I18n.default_locale unless Rails.env.test?
    end

    def error!(*args)
      # Workaround for close transaction on error!
      if !ActiveRecord::Base.connection.transaction_manager.current_transaction.is_a?(ActiveRecord::ConnectionAdapters::NullTransaction)
        ActiveRecord::Base.connection.transaction_open? && ActiveRecord::Base.connection.rollback_transaction
      end
      super(*args)
    end
  end

  before do
    authenticate!
    authorize!
    set_time_zone
    set_locale
    ActiveRecord::Base.connection.begin_transaction
  end

  after do
    begin
      if @error
        ActiveRecord::Base.connection.transaction_open? && ActiveRecord::Base.connection.rollback_transaction
      else
        ActiveRecord::Base.connection.transaction_open? && ActiveRecord::Base.connection.commit_transaction
      end
    rescue Exception
      ActiveRecord::Base.connection.transaction_open? && ActiveRecord::Base.connection.rollback_transaction
      raise
    end
  end

  # Generate a properly formatted 404 error for all unmatched routes except '/'
  route :any, '*path' do
    error! V100::Status.code_response(:code_404, after: "No such route #{request.path}"), 404
  end

  rescue_from :all, backtrace: ENV['RAILS_ENV'] != 'production' do |e|
    ActiveRecord::Base.connection.transaction_open? && ActiveRecord::Base.connection.rollback_transaction

    @error = e
    Rails.logger.error "\n\n#{e.class} (#{e.message}):\n    " + e.backtrace.join("\n    ") + "\n\n"
    puts Rails.backtrace_cleaner.clean(e.backtrace).join("\n    ") if ENV['RAILS_ENV'] == 'development'

    response = {message: e.message}
    if e.is_a?(ActiveRecord::RecordNotFound) || e.is_a?(ArgumentError)
      error!(V100::Status.code_response(:code_404), 404)
    elsif e.is_a?(ActiveRecord::RecordInvalid) || e.is_a?(RangeError) || e.is_a?(Grape::Exceptions::ValidationErrors) || e.is_a?(Exceptions::StopIndexError)
      error!(response.merge(status: 400), 400, e.backtrace)
    elsif e.is_a?(Exceptions::OverMaxLimitError)
      error!(response.merge(status: 403), 403, e.backtrace)
    elsif e.is_a?(Grape::Exceptions::MethodNotAllowed)
      error!(response.merge(status: 405), 405, e.backtrace)
    elsif e.is_a?(Exceptions::JobInProgressError)
      messages = [I18n.t('errors.planning.job_in_progress')]
      response[:message] = messages.join(' ')
      error!(response.merge(status: 409), 409, e.backtrace)
    elsif e.is_a?(PG::TRSerializationFailure) || e.is_a?(PG::TRDeadlockDetected) || e.is_a?(ActiveRecord::StaleObjectError) || e.is_a?(ActiveRecord::StatementInvalid)
      messages = [I18n.t('errors.database.default')]
      if e.is_a?(ActiveRecord::StatementInvalid)
        messages << I18n.t('errors.database.invalid_statement')
      elsif e.is_a?(PG::TRSerializationFailure) || e.is_a?(PG::TRDeadlockDetected) || e.is_a?(ActiveRecord::StaleObjectError)
        messages << I18n.t('errors.database.deadlock')
      end
      response[:message] = messages.join(' ')
      error!(response.merge(status: 409), 409, e.backtrace)
    else
      Sentry.capture_exception(e)
      error!(response.merge(status: 500), 500, e.backtrace)
    end
  end

  mount V100::Plannings
  mount V100::Destinations
  mount V100::Relations
  mount V100::Routes
  mount V100::Stops
end
