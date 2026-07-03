# frozen_string_literal: true

module LookbookHamlToErb
  module Interpolation
    module_function

    def convert(text)
      result = +''
      index = 0

      while index < text.length
        if text[index, 2] == '#{'
          index = append_interpolation(text, index, result)
        else
          result << text[index]
          index += 1
        end
      end

      result
    end

    def append_interpolation(text, index, result)
      if count_trailing_backslashes(text, index - 1).odd?
        result.chop!
        result << '#{'
        return index + 2
      end

      j = find_interpolation_end(text, index + 2)
      raise ArgumentError, "Unclosed interpolation at #{index}" if j.nil?

      result << "<%= #{text[(index + 2)...(j - 1)]} %>"
      j
    end

    def find_interpolation_end(text, start_index)
      depth = 1
      j = start_index
      in_string = nil

      while j < text.length && depth.positive?
        char = text[j]
        if in_string
          in_string = nil if char == in_string && !escaped_character?(text, j)
        elsif ['"', "'"].include?(char)
          in_string = char
        elsif char == '{'
          depth += 1
        elsif char == '}'
          depth -= 1
        end
        j += 1
      end

      depth.positive? ? nil : j
    end

    def escaped_character?(text, index)
      count_trailing_backslashes(text, index - 1).odd?
    end

    def count_trailing_backslashes(text, index)
      count = 0
      while index >= 0 && text[index] == '\\'
        count += 1
        index -= 1
      end
      count
    end
  end
end
