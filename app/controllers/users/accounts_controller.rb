module Users
  class AccountsController < ApplicationController
    before_action :authenticate_user!

    def show
      @user = current_user
      @collections = @user.collections
      @posts = @user.posts.limit(10)
    end
  end
end
