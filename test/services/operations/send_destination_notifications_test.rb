# frozen_string_literal: true

require 'test_helper'

class SendDestinationNotificationsTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    @operation = Operations::PublishFromPlanning.call(planning: @planning, date: Date.current)
    @tracking = @operation.operation_delivery_trackings.first
    stop = @tracking.visit_stops.first
    stop.update!(destination_snapshot: stop.destination_snapshot.merge(
      'phone_number' => '0601020304',
      'email' => 'dest@example.com',
      'name' => 'Alice'
    ))
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'send destination email injects tracking url' do
    @customer.update!(recipient_template: 'Bonjour {NAME} {URL}')
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      count = Operations::SendDestinationEmail.call(operation: @operation, trackings: [@tracking])
      assert_equal 1, count
    end
    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.to, 'dest@example.com'
    assert_match %r{/s/#{Regexp.escape(@tracking.token)}|http}, mail.body.encoded
  end

  test 'destination email subject body and cta share french locale without literal newlines' do
    @customer.update!(recipient_template: nil, company_name: 'Acme')
    @customer.users.update_all(locale: 'fr')
    I18n.with_locale(:en) do
      Operations::SendDestinationEmail.call(operation: @operation, trackings: [@tracking])
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal I18n.t('destination_mailer.delivery_tracking.subject', shipper: 'Acme', locale: :fr), mail.subject
    assert_includes mail.body.encoded, I18n.t('destination_mailer.delivery_tracking.cta', locale: :fr)
    assert_includes mail.body.encoded, I18n.t('destination_mailer.delivery_tracking.fallback_link', locale: :fr)
    assert_includes mail.body.encoded, 'Bonjour'
    assert_not_includes mail.body.decoded, '\\n'
    assert_not_includes mail.body.decoded, 'Suivez votre livraison'
  end

  test 'destination email embeds company logo as inline cid attachment' do
    logo = Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/logo/logo.png'), 'image/png')
    @customer.update!(recipient_template: 'Hi {NAME}', company_logo: logo)
    Operations::SendDestinationEmail.call(operation: @operation, trackings: [@tracking])
    mail = ActionMailer::Base.deliveries.last
    assert mail.attachments.any? { |a| a.filename.start_with?('company_logo') }
    assert_match(%r{cid:}, mail.body.encoded)
  end

  test 'send destination email records timeline without moving status cursor' do
    stop = @tracking.visit_stops.first
    stop.update_columns(status: 'intransit', status_updated_at: 1.hour.ago)
    @customer.update!(recipient_template: 'Bonjour {NAME} {URL}')

    assert_difference -> { stop.operation_stop_status_events.count }, 1 do
      Operations::SendDestinationEmail.call(operation: @operation, trackings: [@tracking])
    end

    event = stop.operation_stop_status_events.order(:id).last
    assert_equal 'email_sent', event.status
    assert_equal 'backoffice', event.source
    assert_equal 'dest@example.com', event.payload['to']
    stop.reload
    assert_equal 'intransit', stop.status
  end

  test 'send destination sms builds content with shortened url' do
    messaging = Object.new
    def messaging.content(template, replacements:, truncate: true)
      "#{replacements[:name]} #{replacements[:url]}"
    end

    # rubocop:disable Naming/PredicateMethod
    def messaging.send_message(*)
      true
    end
    # rubocop:enable Naming/PredicateMethod

    def messaging.class
      Class.new {
        def self.name
          'FakeSms'
        end
      }.new.class
    end

    Operations::SendDriverSms.stubs(:messaging_service).returns(messaging)
    @customer.update!(sms_template: 'Hi {NAME} {URL}')
    count = Operations::SendDestinationSms.call(operation: @operation, trackings: [@tracking])
    assert_equal 1, count
  end

  test 'send destination sms records timeline without moving status cursor' do
    stop = @tracking.visit_stops.first
    stop.update_columns(status: 'intransit', status_updated_at: 1.hour.ago)
    messaging = Object.new
    def messaging.content(template, replacements:, truncate: true)
      'ok'
    end

    # rubocop:disable Naming/PredicateMethod
    def messaging.send_message(*)
      true
    end
    # rubocop:enable Naming/PredicateMethod

    def messaging.class
      Class.new {
        def self.name
          'FakeSms'
        end
      }.new.class
    end

    Operations::SendDriverSms.stubs(:messaging_service).returns(messaging)
    @customer.update!(sms_template: 'Hi {NAME} {URL}')

    assert_difference -> { stop.operation_stop_status_events.count }, 1 do
      Operations::SendDestinationSms.call(operation: @operation, trackings: [@tracking])
    end

    event = stop.operation_stop_status_events.order(:id).last
    assert_equal 'sms_sent', event.status
    assert_equal '0601020304', event.payload['to']
    assert_equal 'intransit', stop.reload.status
  end
end
