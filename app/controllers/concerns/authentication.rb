module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?
  end

  def current_user
    @current_user ||= authenticate_from_token || authenticate_from_session
  end

  def logged_in?
    current_user.present?
  end

  def authenticate_user!
    unless logged_in?
      respond_to do |format|
        format.html { redirect_to login_path, alert: "Please log in" }
        format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
      end
    end
  end

  def require_admin!
    unless current_user&.is_admin?
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Access denied" }
        format.json { render json: { error: "Forbidden" }, status: :forbidden }
      end
    end
  end

  def authorize_resource_owner!(resource)
    unless resource.owner_id == current_user&.id
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Access denied" and return }
        format.json { render json: { error: "Forbidden" }, status: :forbidden and return }
      end
    end
  end

  private

  def authenticate_from_token
    return nil unless request.headers["Authorization"]

    token_string = request.headers["Authorization"]&.remove("Bearer ")
    return nil if token_string.blank?

    access_token = AccessToken.find_by(token: token_string)
    return nil if access_token.nil?
    return nil if access_token.expires_at&.past?

    access_token.user
  end

  def authenticate_from_session
    return nil unless session[:user_id]
    User.find_by(id: session[:user_id])
  end
end
