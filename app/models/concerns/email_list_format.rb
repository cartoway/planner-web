# frozen_string_literal: true

# One or more emails separated by spaces, commas or semicolons.
# Each address is validated after split; CR/LF are rejected (header-injection).
module EmailListFormat
  extend ActiveSupport::Concern

  # Single address: restricted local part (no whitespace / <>:"' / control chars).
  ADDRESS_REGEXP = %r{\A[a-z0-9.!\#$%&'*+/=?^_`{|}~-]+@(?:[-a-z0-9]+\.)+[a-z]{2,}\z}i

  # Horizontal whitespace only — not \n / \r.
  SEPARATOR = /[ \t]*,[ \t]*|[ \t]*;[ \t]*|[ \t]+/

  def self.split(value)
    value.to_s.split(SEPARATOR).reject(&:blank?)
  end

  def self.valid_list?(value)
    return true if value.blank?
    return false if value.to_s.match?(/[\r\n]/)

    emails = split(value)
    emails.any? && emails.all? { |email| email.match?(ADDRESS_REGEXP) }
  end

  class_methods do
    def validates_email_list(*attributes)
      attributes.each do |attribute|
        validate do
          raw = read_attribute(attribute)
          next if raw.blank?

          errors.add(attribute, :invalid) unless EmailListFormat.valid_list?(raw)
        end
      end
    end
  end
end
