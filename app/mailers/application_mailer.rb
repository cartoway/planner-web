class ApplicationMailer < ActionMailer::Base
  helper(EmailHelper)

  default from: Planner::Application.config.default_from_mail
  layout 'mailer'
end
