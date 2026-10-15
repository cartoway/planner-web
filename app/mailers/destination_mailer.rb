# frozen_string_literal: true

class DestinationMailer < ApplicationMailer
  layout false

  def delivery_tracking(customer:, email:, body:, tracking_url:, locale: nil)
    @customer = customer
    @reseller = customer.reseller
    # Templates/locales often store literal "\n"; normalize before simple_format.
    @body = body.to_s.gsub('\\n', "\n")
    @tracking_url = tracking_url
    @shipper_name = customer.company_name.presence || customer.name
    @logo_url = inline_company_logo_url(customer)
    I18n.with_locale(locale.presence || I18n.locale) do
      mail to: EmailListFormat.split(email),
           subject: t('destination_mailer.delivery_tracking.subject', shipper: @shipper_name)
    end
  end

  private

  # Embed the logo as a CID attachment so clients do not need a public host (localhost fails).
  # Skip SVG: most email clients will not render it.
  def inline_company_logo_url(customer)
    uploader = customer.company_logo
    return if uploader.blank? || uploader.file.blank?

    path = uploader.path
    return unless path && File.exist?(path)

    ext = File.extname(path).downcase
    return if ext == '.svg'

    filename = "company_logo#{ext.presence || '.png'}"
    attachments.inline[filename] = {
      mime_type: uploader.content_type.presence || "image/#{ext.delete_prefix('.')}",
      content: File.binread(path)
    }
    attachments[filename].url
  end
end
