# frozen_string_literal: true

class V01::Entities::OperationMediaGroup < Grape::Entity
  def self.entity_name
    'V01_OperationMediaGroup'
  end

  expose(:stop_id) { |group| group[:stop].id }
  expose(:index) { |group| group[:stop].index }
  expose(:label) { |group| group[:stop].address_label }
  expose(:documents) { |group| group[:documents] }
end
