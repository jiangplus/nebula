module Api
  module Auth
    class RegistrationsController < ApplicationController
      skip_before_action :verify_authenticity_token

      def create
        @user = User.new(user_params)

        if @user.save
          token = AccessToken.create!(user: @user)
          render json: {
            access_token: token.token,
            user: { id: @user.id, username: @user.username, email: @user.email }
          }, status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.require(:user).permit(:username, :email, :password, :password_confirmation)
      end
    end
  end
end
