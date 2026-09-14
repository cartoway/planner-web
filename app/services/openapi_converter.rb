# Converts a Grape-swagger Swagger 2.0 Hash into OpenAPI 3.0.3.
# Drop this when grape-swagger emits OAS3 natively (PR ruby-grape/grape-swagger#969).
class OpenapiConverter
  OAS_VERSION = '3.0.3'
  REF_FROM = '#/definitions/'
  REF_TO = '#/components/schemas/'

  def self.convert(swagger)
    new(swagger).convert
  end

  def initialize(swagger)
    @src = deep_stringify(swagger)
  end

  def convert
    info = @src['info'] || {}
    out = {
      'openapi' => OAS_VERSION,
      'info' => info,
      'servers' => servers,
      'paths' => convert_paths(@src['paths'] || {}),
      'components' => components
    }
    out['tags'] = @src['tags'] if @src['tags']
    out['security'] = @src['security'] if @src['security']
    promote_nullable!(out)
    rewrite_refs!(out)
    out
  end

  private

  def servers
    base = Planner::Application.config.swagger_docs_base_path.to_s.chomp('/')
    base = 'http://localhost:8080' if base.empty?
    [{ 'url' => base }]
  end

  def components
    schemas = @src['definitions'] || {}
    security = @src['securityDefinitions'] || {}
    {
      'schemas' => schemas,
      'securitySchemes' => convert_security_schemes(security)
    }.reject { |_k, v| v.nil? || v.empty? }
  end

  def convert_security_schemes(defs)
    defs.each_with_object({}) do |(name, scheme), acc|
      acc[name] = scheme.dup
    end
  end

  def convert_paths(paths)
    paths.each_with_object({}) do |(path, item), acc|
      next unless item.is_a?(Hash)

      acc[path] = item.each_with_object({}) do |(method, operation), ops|
        if %w[get put post delete options head patch trace].include?(method)
          ops[method] = convert_operation(operation)
        else
          ops[method] = operation
        end
      end
    end
  end

  def convert_operation(operation)
    return operation unless operation.is_a?(Hash)

    op = operation.dup
    params = Array(op.delete('parameters'))
    consumes = op.delete('consumes') || @src['consumes'] || ['application/json']
    produces = op.delete('produces') || @src['produces'] || ['application/json']

    body, form, rest = split_params(params)
    op['parameters'] = rest.map { |p| convert_parameter(p) } unless rest.empty?

    request_body = request_body_from(body, form, consumes)
    op['requestBody'] = request_body if request_body

    op['responses'] = convert_responses(op['responses'] || {}, produces)
    op
  end

  def split_params(params)
    body = []
    form = []
    rest = []
    params.each do |param|
      case param['in']
      when 'body' then body << param
      when 'formData' then form << param
      else rest << param
      end
    end
    [body, form, rest]
  end

  def convert_parameter(param)
    p = param.dup
    schema = p.delete('schema') || {}
    %w[type format items enum default description example].each do |key|
      schema[key] = p.delete(key) if p.key?(key) && !schema.key?(key)
    end
    schema['type'] ||= 'string' if schema.empty?
    if schema['type'] == 'file'
      schema['type'] = 'string'
      schema['format'] ||= 'binary'
    end
    p['schema'] = schema unless schema.empty?
    p['required'] = true if p['in'] == 'path'
    p
  end

  def request_body_from(body_params, form_params, consumes)
    if body_params.any?
      schema = body_params.size == 1 ? (body_params.first['schema'] || { 'type' => 'object' }) : object_schema_from(body_params)
      required = body_params.any? { |p| p['required'] }
      return {
        'required' => required,
        'content' => content_for(consumes, schema)
      }
    end
    return if form_params.empty?

    schema = object_schema_from(form_params)
    multipart = form_params.any? { |p| p['type'] == 'file' }
    mime = multipart ? 'multipart/form-data' : 'application/x-www-form-urlencoded'
    {
      'required' => form_params.any? { |p| p['required'] },
      'content' => { mime => { 'schema' => schema } }
    }
  end

  def object_schema_from(params)
    properties = {}
    required = []
    params.each do |param|
      name = param['name']
      next unless name

      properties[name] = param['schema'] || { 'type' => param['type'] || 'string' }
      properties[name]['format'] = param['format'] if param['format']
      properties[name]['description'] = param['description'] if param['description']
      required << name if param['required']
    end
    schema = { 'type' => 'object', 'properties' => properties }
    schema['required'] = required if required.any?
    schema
  end

  def content_for(consumes, schema)
    mimes = Array(consumes)
    mimes = ['application/json'] if mimes.empty?
    mimes.each_with_object({}) { |mime, acc| acc[mime] = { 'schema' => schema } }
  end

  def convert_responses(responses, produces)
    responses.each_with_object({}) do |(code, response), acc|
      unless response.is_a?(Hash)
        acc[code] = response
        next
      end
      r = response.dup
      schema = r.delete('schema')
      examples = r.delete('examples')
      if schema
        content = content_for(produces, schema)
        if examples.is_a?(Hash)
          examples.each do |mime, example|
            content[mime] ||= { 'schema' => schema }
            content[mime]['example'] = example
          end
        end
        r['content'] = content
      elsif examples.is_a?(Hash)
        r['content'] = examples.each_with_object({}) { |(mime, example), c| c[mime] = { 'example' => example } }
      end
      r['description'] ||= ''
      acc[code] = r
    end
  end

  def promote_nullable!(node)
    case node
    when Hash
      if node.delete('x-nullable')
        node['nullable'] = true
      end
      node.each_value { |v| promote_nullable!(v) }
    when Array
      node.each { |v| promote_nullable!(v) }
    end
  end

  def rewrite_refs!(node)
    case node
    when Hash
      node['$ref'] = node['$ref'].sub(REF_FROM, REF_TO) if node['$ref'].is_a?(String)
      node.each_value { |v| rewrite_refs!(v) }
    when Array
      node.each { |v| rewrite_refs!(v) }
    end
  end

  def deep_stringify(obj)
    case obj
    when Hash
      obj.each_with_object({}) { |(k, v), acc| acc[k.to_s] = deep_stringify(v) }
    when Array
      obj.map { |v| deep_stringify(v) }
    else
      obj
    end
  end
end
