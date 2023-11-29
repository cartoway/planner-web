class V100::Status < Grape::API
  def self.status_codes
    {
      code_200: { code: 200, message: 'OK.' },
      code_201: { code: 201, message: 'Created.' },
      code_202: { code: 202, message: 'Accepted.' },
      code_204: { code: 204, message: 'No Content.' },
      code_304: { code: 304, message: 'Not modified.', model: V100::Entities::Status304 },
      code_400: { code: 400, message: 'Bad request.', model: V100::Entities::Status400 },
      code_401: { code: 401, message: 'Unauthorized.', model: V100::Entities::Status401 },
      code_402: { code: 402, message: 'Subscription error.', model: V100::Entities::Status402 },
      code_403: { code: 403, message: 'Forbidden.', model: V100::Entities::Status403 },
      code_404: { code: 404, message: 'Not found.', model: V100::Entities::Status404 },
      code_405: { code: 405, message: 'Method not allowed.', model: V100::Entities::Status405 },
      code_409: { code: 409, message: 'Conflict.', model: V100::Entities::Status409 },
      code_422: { code: 422, message: 'Unprocessable entity.', model: V100::Entities::Status422 },
      code_500: { code: 500, message: 'Internal servor error.', model: V100::Entities::Status500 }
    }
  end

  def self.success(code, model = nil)
    status_codes.key?(code) ? status_codes[code].merge(model: model) : {}
  end

  def self.failures(params = {is_array: false, add: nil, override: nil })
    failure_codes = status_codes
    responses = [:code_400, :code_401, :code_402, :code_403, :code_404, :code_405, :code_409, :code_500]
    params[:override]&.each { |code, message| failure_codes[code][:message] = message }
    params[:add]&.each { |code| responses.push(code) if failure_codes.key?(code) }
    responses.map! { |code| failure_codes[code] }
    responses.map! { |response| response.reject!{ |k| (k == :model) } } if params[:is_array]
    responses
  end

  def self.code_response(code, params = { before: nil, after: nil })
    message = params[:before] ? "#{params[:before]} #{status_codes[code][:message].downcase}" : status_codes[code][:message]
    message = "#{message} #{params[:after]}" if params[:after]
    {
      'message': message,
      'status': status_codes[code][:code]
    }
  end
end
