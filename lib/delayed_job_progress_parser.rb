module DelayedJobProgressParser
  def self.included(base)
    base.class_eval do
      def progress
        parsed_progress = self[:progress]
        begin
          JSON.parse(parsed_progress) if parsed_progress.present? && !parsed_progress.is_a?(Hash)
        rescue JSON::ParserError
          parsed_progress
        end
      end

      def progress=(value)
        @parsed_progress = nil
        self[:progress] = value.is_a?(String) ? value : value.to_json
      end
    end
  end
end

Delayed::Job.include DelayedJobProgressParser
