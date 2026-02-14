class RegistrationsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create], if: -> { request.format.json? }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      respond_to do |format|
        format.html do
          session[:user_id] = @user.id
          redirect_to user_account_path, notice: "Account created successfully"
        end

        format.json do
          token = AccessToken.create!(user: @user)
          render json: {
            access_token: token.token,
            user: { id: @user.id, username: @user.username, email: @user.email }
          }, status: :created
        end
      end
    else
      respond_to do |format|
        format.html do
          render :new, status: :unprocessable_entity
        end

        format.json do
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :email, :password, :password_confirmation)
  end
end
