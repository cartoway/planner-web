# Serves OpenAPI 3.0.3 by converting the grape-swagger Swagger 2.0 document.
# Mounted on ApiV01 / ApiV100 (unauthenticated), not inside V01::Api.
module OpenapiJson
  def self.included(api)
    api.class_eval do
      helpers do
        def openapi_from_swagger
          swagger_path = "/#{version}/swagger_doc"
          response = Rack::MockRequest.new(ApiRootDef).get(swagger_path)
          error!({ message: 'Failed to build Swagger 2.0 document', status: 500 }, 500) unless response.status == 200
          OpenapiConverter.convert(JSON.parse(response.body), scope: params[:scope])
        end
      end

      desc 'OpenAPI 3.0.3 descriptor converted from Swagger 2.0 (grape-swagger). Import this in codegen, Postman or Insomnia. GET swagger_doc remains the Swagger 2.0 source. Operations are tagged happy_path, core, admin and devices. Pass scope=happy_path or scope=core to drop the rest.'
      params do
        optional :scope, type: String, values: ->(v) { v.nil? || %w[core happy_path].include?(v) }, desc: 'happy_path is the getting-started numbered flow. core drops admin and devices. Omit for the full catalog.'
      end
      get :openapi do
        openapi_from_swagger
      end
    end
  end
end
