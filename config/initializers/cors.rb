Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource(
      '/api/*',
      headers: :any,
      methods: :any,
      expose: ['Cache-Control', 'Content-Encoding', 'Content-Type'],
      max_age: 1728000
    )
    resource(
      '/api-web/*',
      headers: :any,
      methods: :any,
      expose: ['Cache-Control', 'Content-Encoding', 'Content-Type'],
      max_age: 1728000
    )
  end
end
