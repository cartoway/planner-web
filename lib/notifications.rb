# Copyright © Mapotempo, 2018
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
require 'active_support/core_ext/numeric'

class CountryCodeNotFoundError < StandardError; end

#
# Usage:
# notif = Notifications.new(service: :vonage, api_key: XXX, api_secret: XXX, logger: XXX)
# notif.send_sms(to, country, notif.content(template, name: XXX, time: XXX), message_id)
#
class Notifications

  def initialize(options)
    @options = options
    @options[:service] ||= :vonage
  end

  def content(template, replacements = {}, truncate = true)
    # Display date only if key date is not present in template
    format_time = template.include?('{DATE}') ? :hour_minute : :short

    replacements.each{ |k, v|
      if v.is_a?(Time)
        # Shift time if {TIME+mn} or {TIME-mn} found in template
        regexp = Regexp.new("{#{k}([\-\+]?[0-9]*)}".upcase)
        template = template.gsub(regexp) { |s|
          shift_time = 0
          if m = regexp.match(s)
            shift_time = Integer(m[1]).minutes unless m[1].blank?
          end

          if shift_time != 0
            # Round time to quarter
            seconds = 15.minutes
            shift_time = (shift_time / shift_time.abs) * seconds if shift_time.abs < seconds
            shift_time = ((v + shift_time).to_f / seconds).round * seconds - v.to_i
          end

          I18n.l(v + shift_time, format: format_time)
        }
      else
        template = template.gsub("{#{k}}".upcase, "#{v}")
      end
    }

    truncate ? template[0..159] : template
  end

  def send_sms(to, country, content, message_id)
    country_code = nil
    unless to.start_with?('+', '00')
      begin
        country_code = IsoCountryCodes.search_by_name(country).first.alpha2
      rescue IsoCountryCodes::UnknownCodeError => e
      end
    end
    phone = Phonelib.parse(to, country_code)

    return [] unless phone.type == :mobile

    if phone.country_code
      to = phone.country_code + phone.raw_national

      if @options[:service] == :vonage
        client = Vonage::Client.new(api_key: @options[:api_key], api_secret: @options[:api_secret])
        content = I18n.transliterate(content)
        response = client.sms.send(from: @options[:from].gsub(/[^0-9a-z]+/i, '')[0..10], to: to, text: content, message_id: message_id)

        response.messages.map{ |message|
          if @options[:logger]
            if message.status == '0'
              @options[:logger].info "Sent SMS\t#{message_id}\t#{message.message_id}\t#{message.message_price}"
            else
              @options[:logger].error "SMS error\t#{message_id}\t#{message.error_text}"
            end
          end
          message.status == '0'
        }
      end
    else
      raise CountryCodeNotFoundError.new("Country code could not be identified: #{to} #{country_code}")
    end
  end

end
