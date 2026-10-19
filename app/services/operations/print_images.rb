# frozen_string_literal: true

module Operations
  # Resize ActiveStorage images for print/PDF (shared by BL UI and export).
  module PrintImages
    MAX_EDGE = 880
    JPEG_QUALITY = 70

    module_function

    def embedded(attachment, resize: true)
      bytes, content_type = bytes_for(attachment, resize: resize)
      {
        filename: attachment.blob.filename.to_s,
        url: "data:#{content_type};base64,#{Base64.strict_encode64(bytes)}"
      }
    end

    def bytes_for(attachment, resize: true)
      blob = attachment.blob
      return [blob.download, blob.content_type] unless resize && attachment.variable?

      processed = attachment.variant(
        resize_to_limit: [MAX_EDGE, MAX_EDGE],
        format: :jpeg,
        saver: { quality: JPEG_QUALITY, strip: true }
      ).processed
      [processed.download, 'image/jpeg']
    rescue StandardError => e
      Rails.logger.warn("print image resize failed (#{e.class}): #{e.message}")
      [blob.download, blob.content_type]
    end

    def company_logo_data_uri(customer)
      uploader = customer.company_logo
      return if uploader.blank? || uploader.url.blank?

      path = uploader.respond_to?(:path) ? uploader.path : nil
      if path.present? && File.readable?(path)
        bytes = File.binread(path)
        type = uploader.content_type.presence || Marcel::MimeType.for(Pathname.new(path)) || 'image/png'
        return "data:#{type};base64,#{Base64.strict_encode64(bytes)}"
      end

      uploader.url
    rescue StandardError => e
      Rails.logger.warn("company logo embed failed (#{e.class}): #{e.message}")
      uploader.url
    end
  end
end
