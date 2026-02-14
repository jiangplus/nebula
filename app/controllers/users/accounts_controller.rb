module Users
  class AccountsController < ApplicationController
    before_action :authenticate_user!

    def show
      @user = current_user
      @collections = @user.collections
      @posts = @user.posts.limit(10)
    end

    def update
      @user = current_user

      if @user.update(account_params)
        redirect_to user_account_path, notice: "Settings updated"
      else
        flash.now[:alert] = @user.errors.full_messages.join(", ")
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      @user = current_user

      if params[:confirm_username] == @user.username
        @user.destroy!
        session.delete(:user_id)
        redirect_to root_path, notice: "Account deleted"
      else
        redirect_to user_account_path, alert: "Username confirmation didn't match"
      end
    end

    private

    def account_params
      params.require(:user).permit(:username, :email, :password, :password_confirmation)
    end
  end
end
