# frozen_string_literal: true

# Vendored from haml_to_erb (MIT) — https://github.com/kurioscreative/haml_to_erb
require 'prism'

module LookbookHamlToErb
  class PrismParser
    def parse_hash(str)
      content = str.strip
      content = "{#{content}}" unless content.start_with?('{')

      result = Prism.parse(content)
      return nil if result.errors.any?

      statements = result.value.statements.body
      return nil unless statements.length == 1

      extract_value(statements.first)
    end

    def parse_array(str)
      result = Prism.parse(str.strip)
      return nil if result.errors.any?

      statements = result.value.statements.body
      return nil unless statements.length == 1

      extract_value(statements.first)
    end

    private

    def extract_value(node)
      case node
      when Prism::HashNode then extract_hash(node)
      when Prism::ArrayNode then extract_array(node)
      when Prism::StringNode then node.unescaped
      when Prism::SymbolNode then node.unescaped.to_sym
      when Prism::IntegerNode then node.value
      when Prism::FloatNode then node.value
      when Prism::TrueNode then true
      when Prism::FalseNode then false
      when Prism::NilNode then nil
      else nil
      end
    end

    def extract_hash(node)
      result = {}
      node.elements.each do |element|
        case element
        when Prism::AssocNode
          key = extract_key(element.key)
          return nil if key.nil?

          value = extract_value(element.value)
          return nil if value.nil?

          result[key] = value
        else
          return nil
        end
      end
      result
    end

    def extract_array(node)
      result = []
      node.elements.each do |element|
        value = extract_value(element)
        return nil if value.nil?

        result << value
      end
      result
    end

    def extract_key(node)
      case node
      when Prism::SymbolNode then node.unescaped.to_sym
      when Prism::StringNode then node.unescaped
      else nil
      end
    end
  end
end
