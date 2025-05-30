class CountryCodeError < StandardError; end

require 'application_helper'

class MessagingService
  include ApplicationHelper

  def self.definition
    raise NotImplementedError
  end

  def self.get_messaging_service_from_key(key)
    MESSAGING_SERVICES[key]
  end

  def initialize(reseller, options = {})
    @reseller = reseller
    @options = options
  end

  def send_message(to, content, options = {})
    raise NotImplementedError
  end

  def balance
    raise NotImplementedError
  end

  def content(template, replacements: {}, truncate: true, time_format: nil)
    # Display date only if key date is not present in template
    format_time = time_format || (template.include?('{DATE}') ? :hour_minute : :short)

    replacements.each{ |k, v|
      if v.is_a?(Time)
        # Shift time if {TIME+mn} or {TIME-mn} found in template
        regexp = Regexp.new("{#{k}([\-\+]?[0-9]*)}".upcase)
        template = template.gsub(regexp) { |s|
          shift_time = 0
          if (m = regexp.match(s)) && !m[1].blank?
            shift_time = Integer(m[1]).minutes
          end
          time = v + shift_time
          if shift_time != 0
            time = round_time_to_nearest_quarter(time)
          end

          I18n.l(time, format: format_time)
        }
      elsif v.is_a?(Date)
        template = template.gsub("{#{k}}".upcase, I18n.l(v, format: :date))
      elsif k == :url && v.is_a?(String) && template.include?('{URL}')
        template = template.gsub("{#{k}}".upcase, Rails.application.config.url_shortener.shorten(v))
      else
        template = template.gsub("{#{k}}".upcase, "#{v}")
      end
    }

    truncate ? template[0..159] : template
  end

  def self.configured?(reseller, service_name)
    return false unless reseller.messagings&.key?(service_name)

    config = reseller.messagings[service_name]
    ValueToBoolean.value_to_boolean(config['enable'])
  end

  def service_name
    self.class.name.split('::').last.underscore.gsub('_service', '')
  end

  def format_phone_number(phone, country = nil)
    return phone if phone.start_with?('+', '00')

    if country
      begin
        country_code = IsoCountryCodes.search_by_name(country).first.alpha2
        raise CountryCodeError.new("Country code could not be identified: #{to} #{country_code}") unless country_code

        formatted_phone = Phonelib.parse(phone, country_code)
        return [] unless formatted_phone.type == :mobile

        "+#{formatted_phone.country_code}#{formatted_phone.raw_national}"
      rescue IsoCountryCodes::UnknownCodeError => e
        Rails.logger.error "Country code error: #{e.message}"
        raise CountryCodeError.new(e.message)
      end
    else
      raise CountryCodeError.new("Country is mandatory if the number is not in an international format")
    end
  end

  protected

  def service_config
    @reseller.messagings&.dig(service_name) || {}
  end

  def create_message_log(to, content, response = {})
    return unless @options[:customer]

    @options[:customer].messaging_logs.create!(
      service: service_name,
      recipient: to,
      content: content,
      details: response
    )
  end
end
