class V01::EmbedTokens < Grape::API
  helpers SharedParams

  resource :embed_tokens do
    desc 'Create a short-lived api-web embed token.',
      detail: 'Mint a token for iframe / LLM views. Pass it as embed_token query, Embed-Token header, or Authorization: Bearer. Optional origin locks CSP frame-ancestors. Do not put the user api_key in the iframe URL.',
      nickname: 'createEmbedToken',
      http_codes: [
        V01::Status.success(:code_201)
      ].concat(V01::Status.failures)
    params do
      optional :expires_in, type: Integer, desc: 'Lifetime in seconds (min 60, max 86400). Default 3600.'
      optional :origin, type: String, desc: 'Allowed iframe parent origin (scheme + host), e.g. https://erp.example.com.'
    end
    post do
      if params[:origin].present? && ApiWebEmbedToken.sanitize_origin(params[:origin]).nil?
        error! V01::Status.code_response(:code_400, message: 'Invalid origin.'), 400
      end

      issued = ApiWebEmbedToken.issue!(
        @current_user,
        expires_in: params[:expires_in] || ApiWebEmbedToken::DEFAULT_TTL,
        origin: params[:origin]
      )
      status 201
      {
        token: issued[:token],
        expires_at: issued[:expires_at].iso8601,
        origin: issued[:origin]
      }
    end
  end
end
