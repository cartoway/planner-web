class ApplicationMailer < ActionMailer::Base
  helper(EmailHelper)

  default from: Planner::Application.config.default_from_mail
  layout 'mailer'

  after_action :add_provider_tags

  private

  def add_provider_tags
    MailTagHeaders.apply!(message, provider_tags, provider: self.class.smtp_provider)
  end

  def provider_tags
    tags = []
    tags << "mail_type:#{action_name}" if action_name.present?
    reseller_id = mail_reseller_id
    customer_id = mail_customer_id
    tags << "reseller_id:#{reseller_id}" if reseller_id
    tags << "customer_id:#{customer_id}" if customer_id
    tags
  end

  def mail_reseller_id
    @reseller&.id || @customer&.reseller_id || @user&.customer&.reseller_id || @user&.reseller_id
  end

  def mail_customer_id
    @customer&.id || @user&.customer_id
  end
end
