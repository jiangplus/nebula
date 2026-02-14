module Api
  class UsersController < ApplicationController
    before_action :authenticate_user!

    def show
      render json: {
        id: current_user.id,
        username: current_user.username,
        email: current_user.email,
        is_admin: current_user.is_admin
      }
    end
  end
end
