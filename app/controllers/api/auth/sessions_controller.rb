module Api
  module Auth
    class SessionsController < ApplicationController
      skip_before_action :verify_authenticity_token

      def create
        user = User.find_by(username: params[:username])

        if user&.authenticate(params[:password])
          token = AccessToken.create!(user: user)
          render json: {
            access_token: token.token,
            user: { id: user.id, username: user.username, email: user.email }
          }, status: :created
        else
          render json: { error: "Invalid credentials" }, status: :unauthorized
        end
      end

      def destroy
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
