class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create], if: -> { request.format.json? }

  def new
    # Render login form
  end

  def create
    user = User.find_by(username: params[:username])

    if user&.authenticate(params[:password])
      respond_to do |format|
        format.html do
          session[:user_id] = user.id
          redirect_to user_account_path, notice: "Logged in successfully"
        end

        format.json do
          token = AccessToken.create!(user: user)
          render json: {
            access_token: token.token,
            user: { id: user.id, username: user.username, email: user.email }
          }, status: :created
        end
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = "Invalid username or password"
          render :new, status: :unprocessable_entity
        end

        format.json do
          render json: { error: "Invalid credentials" }, status: :unauthorized
        end
      end
    end
  end

  def destroy
    respond_to do |format|
      format.html do
        session.delete(:user_id)
        redirect_to root_path, notice: "Logged out successfully"
      end

      format.json do
        if current_user
          AccessToken.where(user: current_user).destroy_all
          render json: { message: "Logged out" }, status: :ok
        else
          head :no_content
        end
      end
    end
  end
end
