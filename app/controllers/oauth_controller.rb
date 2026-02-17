class OauthController < ApplicationController
  skip_before_action :verify_authenticity_token

  def authorize
    provider = params[:provider]
    state = SecureRandom.hex(32)

    oauth_state = OAuthClientState.create!(
      state: state,
      provider: provider,
      client_id: oauth_config(provider)[:client_id]
    )

    auth_url = build_oauth_url(provider, state)
    redirect_to auth_url, allow_other_host: true
  end

  def callback
    provider = params[:provider]
    code = params[:code]
    state = params[:state]

    oauth_state = OAuthClientState.find_by(state: state, provider: provider, used: false)
    return render json: { error: "Invalid state" }, status: :unauthorized if oauth_state.nil?

    oauth_state.update(used: true)

    # Exchange code for token with OAuth provider
    token_response = exchange_code_for_token(provider, code)
    return render json: { error: "Failed to get token" }, status: :unauthorized if token_response.nil?

    user_info = fetch_user_info(provider, token_response[:access_token])
    return render json: { error: "Failed to get user info" }, status: :unauthorized if user_info.nil?

    # Find or create OAuth user
    oauth_user = OAuthUser.find_or_create_by(
      provider: provider,
      client_id: oauth_state.client_id,
      remote_user_id: user_info[:id]
    )

    # Find or create user
    unless oauth_user.user
      user = User.create!(
        username: user_info[:username] || user_info[:email],
        email: user_info[:email] || "#{provider}-#{user_info[:id]}@example.com"
      )
      oauth_user.update(user: user)
    end

    session[:user_id] = oauth_user.user.id
    redirect_to user_account_path, notice: "Logged in successfully"
  end

  private

  def oauth_config(provider)
    Rails.application.credentials.dig(:oauth, provider.to_sym) || {}
  end

  def build_oauth_url(provider, state)
    case provider.to_s
    when "github"
      "https://github.com/login/oauth/authorize?" + {
        client_id: oauth_config(provider)[:client_id],
        redirect_uri: oauth_callback_url(provider),
        state: state,
        scope: "user:email"
      }.to_query
    when "google"
      "https://accounts.google.com/o/oauth2/v2/auth?" + {
        client_id: oauth_config(provider)[:client_id],
        redirect_uri: oauth_callback_url(provider),
        response_type: "code",
        scope: "openid email profile",
        state: state
      }.to_query
    else
      raise "Unknown OAuth provider: #{provider}"
    end
  end

  def exchange_code_for_token(provider, code)
    # This is a simplified implementation
    # In production, use the specific OAuth gem for your provider
    uri = case provider.to_s
          when "github"
            URI("https://github.com/login/oauth/access_token")
          when "google"
            URI("https://oauth2.googleapis.com/token")
          end

    params = {
      client_id: oauth_config(provider)[:client_id],
      client_secret: oauth_config(provider)[:client_secret],
      code: code,
      redirect_uri: oauth_callback_url(provider)
    }

    response = Net::HTTP.post_form(uri, params)
    parse_token_response(response.body, provider)
  rescue StandardError => e
    Rails.logger.error("OAuth token exchange failed: #{e.message}")
    nil
  end

  def parse_token_response(body, provider)
    case provider.to_s
    when "github"
      params = Rack::Utils.parse_query(body)
      { access_token: params["access_token"] }
    when "google"
      JSON.parse(body).slice("access_token", "id_token").symbolize_keys
    end
  end

  def fetch_user_info(provider, access_token)
    uri = case provider.to_s
          when "github"
            URI("https://api.github.com/user")
          when "google"
            URI("https://www.googleapis.com/oauth2/v2/userinfo")
          end

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

    parse_user_info(JSON.parse(response.body), provider)
  rescue StandardError => e
    Rails.logger.error("Failed to fetch user info: #{e.message}")
    nil
  end

  def parse_user_info(data, provider)
    case provider.to_s
    when "github"
      { id: data["id"], username: data["login"], email: data["email"] }
    when "google"
      { id: data["id"], username: data["email"], email: data["email"] }
    end
  end

  def oauth_callback_url(provider)
    auth_oauth_callback_url(provider: provider)
  end
end
