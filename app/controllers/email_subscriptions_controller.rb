class EmailSubscriptionsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    @collection = Collection.find_by(alias: params[:collection_alias])
    return render json: { error: "Collection not found" }, status: :not_found if @collection.nil?

    email = params[:email] || current_user&.email
    return render json: { error: "Email is required" }, status: :unprocessable_entity if email.blank?

    subscriber = EmailSubscriber.create(
      collection: @collection,
      user: current_user,
      email: email,
      confirmed: current_user.present?
    )

    if subscriber.persisted?
      # In a real app, send confirmation email
      # EmailSubscriptionMailer.send_confirmation(subscriber).deliver_later
      render json: { message: "Check your email to confirm subscription" }, status: :created
    else
      render json: { errors: subscriber.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @collection = Collection.find_by(alias: params[:collection_alias])
    return render json: { error: "Collection not found" }, status: :not_found if @collection.nil?

    subscriber = EmailSubscriber.find_by(
      collection: @collection,
      token: params[:token]
    )

    if subscriber.present?
      subscriber.destroy
      render json: { message: "Unsubscribed successfully" }, status: :ok
    else
      render json: { error: "Subscription not found" }, status: :not_found
    end
  end

  def confirm
    subscriber = EmailSubscriber.find_by(token: params[:token], confirmed: false)

    if subscriber.present?
      subscriber.update(confirmed: true)
      render :confirmed
    else
      render :invalid, status: :not_found
    end
  end
end
