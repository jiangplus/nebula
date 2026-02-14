class PasswordResetsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create, :update], if: -> { request.format.json? }

  def new
    # Render password reset request form
  end

  def create
    user = User.find_by(email: params[:email])

    if user.present?
      auth_code = AuthCode.create!(code_type: "password_reset", user: user)
      # In a real app, send email with reset link
      # PasswordResetMailer.send_reset_email(user, auth_code).deliver_later
    end

    respond_to do |format|
      format.json do
        render json: { message: "If an account exists with that email, a password reset link has been sent" }, status: :ok
      end

      format.html do
        flash[:notice] = "If an account exists with that email, a password reset link has been sent"
        redirect_to login_path
      end
    end
  end

  def edit
    @auth_code = AuthCode.find_by(token: params[:token], code_type: "password_reset", used: false)
    redirect_to login_path, alert: "Invalid or expired password reset link" if @auth_code.nil?
  end

  def update
    @auth_code = AuthCode.find_by(token: params[:token], code_type: "password_reset", used: false)

    if @auth_code.nil?
      render json: { error: "Invalid or expired password reset link" }, status: :unprocessable_entity
      return
    end

    user = @auth_code.user

    if user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      @auth_code.update(used: true)

      respond_to do |format|
        format.json do
          render json: { message: "Password reset successfully" }, status: :ok
        end

        format.html do
          redirect_to login_path, notice: "Password reset successfully. Please log in."
        end
      end
    else
      respond_to do |format|
        format.json do
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end

        format.html do
          render :edit, status: :unprocessable_entity
        end
      end
    end
  end
end
