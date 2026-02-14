class AdminController < ApplicationController
  before_action :require_admin!

  def dashboard
    @users_count = User.count
    @collections_count = Collection.count
    @posts_count = Post.count
    @recent_users = User.order(created_at: :desc).limit(10)
  end

  def users_index
    @users = User.all
  end

  def show_user
    @user = User.find(params[:id])
  end

  def delete_user
    @user = User.find(params[:id])
    @user.destroy!
    redirect_to admin_users_path, notice: "User deleted successfully"
  end

  def toggle_user_status
    @user = User.find(params[:id])
    @user.update(is_admin: !@user.is_admin?)
    redirect_to admin_show_user_path(@user), notice: "User status updated"
  end
end
