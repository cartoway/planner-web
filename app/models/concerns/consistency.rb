# Copyright © Mapotempo, 2017
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

module Consistency
  extend ActiveSupport::Concern

  included do
    attr_accessor :force_check_consistency
  end

  class_methods do
    # Attributes must have a defined #{attr_name}_changed? method
    def validate_consistency(attributes, &block)
      validate do |record|
        consistent_value = block ? block.call(record) : record.send(:customer_id)
        if consistent_value
          attributes.each{ |attr|
            attr = attr.to_s.gsub(/^(.+[^s])(s?)$/, '\1_id\2').to_sym unless attr.to_s =~ /_ids?$/

            if record.force_check_consistency || record.send("#{attr}_changed?".to_sym)
              model_ids = nil
              model_name = attr.to_s.gsub(/_id(s?)$/, '\1').to_sym
              models = record.send(model_name)
              models = [models].compact unless models.is_a? ActiveRecord::Associations::CollectionProxy
              model_ids = models.map(&:id).compact
              record.errors.add(model_name, message: "#{model_ids.any? ? model_ids.join(',') : consistent_value} " + I18n.t('activerecord.errors.attributes.inconsistent_customer')) if models.any?{ |m| m.customer_id != consistent_value }
            end
          }
        end
      end
    end
  end

end
