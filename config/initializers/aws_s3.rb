# S3-compatible stores (RustFS) reject the default AWS request checksums.
ENV['AWS_REQUEST_CHECKSUM_CALCULATION'] ||= 'WHEN_REQUIRED'
ENV['AWS_RESPONSE_CHECKSUM_VALIDATION'] ||= 'WHEN_REQUIRED'
