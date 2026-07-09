# frozen_string_literal: true

# Vendored from haml_to_erb (MIT) — https://github.com/kurioscreative/haml_to_erb
module LookbookHamlToErb
  module Interpolation
    module_function

    def convert(text)
      result = +''
      offset = 0

      while offset < text.length
        if text[offset, 2] == '#{'
          offset = consume_interpolation(text, offset, result)
        else
          result << text[offset]
          offset += 1
        end
      end

      result
    end

    def consume_interpolation(text, offset, result)
      if odd_backslashes_before?(text, offset)
        result.chop!
        result << '#{'
        return offset + 2
      end

      close_index = find_interpolation_close(text, offset + 2)
      raise ArgumentError, "Unclosed interpolation at #{offset}" unless close_index

      result << "<%= #{text[(offset + 2)...(close_index - 1)]} %>"
      close_index
    end

    def find_interpolation_close(text, start_index)
      depth = 1
      index = start_index
      in_string = nil

      while index < text.length && depth.positive?
        char = text[index]
        in_string = update_string_state(text, index, char, in_string)
        depth = update_depth(char, depth) unless in_string
        index += 1
      end

      depth.positive? ? nil : index
    end

    def update_string_state(text, index, char, in_string)
      if in_string
        return nil if char == in_string && !odd_backslashes_before?(text, index)

        in_string
      elsif ['"', "'"].include?(char)
        char
      end
    end

    def update_depth(char, depth)
      case char
      when '{' then depth + 1
      when '}' then depth - 1
      else depth
      end
    end

    def odd_backslashes_before?(text, index)
      trailing_backslash_count(text, index - 1).odd?
    end

    def trailing_backslash_count(text, index)
      count = 0
      while index >= 0 && text[index] == '\\'
        count += 1
        index -= 1
      end
      count
    end
  end
end
