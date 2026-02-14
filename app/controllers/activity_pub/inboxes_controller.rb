module ActivityPub
  class InboxesController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_collection

    def create
      activity = params.permit!.to_h

      case activity["type"]
      when "Follow"
        handle_follow(activity)
      when "Undo"
        handle_undo(activity)
      when "Like", "Announce"
        handle_engagement(activity)
      else
        Rails.logger.info("Received unknown ActivityPub activity: #{activity['type']}")
      end

      head :accepted
    end

    private

    def set_collection
      @collection = Collection.find_by(alias: params[:collection_alias])
      return head :not_found if @collection.nil?
    end

    def handle_follow(activity)
      actor_id = activity["actor"]
      return if actor_id.blank?

      # Find or create remote user
      remote_user = RemoteUser.find_or_create_by(actor_id: actor_id)

      # Check if already following
      return if RemoteFollow.exists?(remote_user: remote_user, collection: @collection)

      # Create follow request
      RemoteFollowRequest.create!(
        remote_user: remote_user,
        collection: @collection
      )

      # In a real app, send Accept activity
      # ActivityPubService.send_accept(@collection, activity)
    end

    def handle_undo(activity)
      object = activity["object"]
      return if object.blank?

      case object["type"]
      when "Follow"
        actor_id = object["actor"] || activity["actor"]
        remote_user = RemoteUser.find_by(actor_id: actor_id)
        return if remote_user.nil?

        RemoteFollow.where(remote_user: remote_user, collection: @collection).destroy_all
        RemoteFollowRequest.where(remote_user: remote_user, collection: @collection).destroy_all
      end
    end

    def handle_engagement(activity)
      # Track likes, announces, etc.
      # In a real app, store engagement metrics
      Rails.logger.info("Received engagement: #{activity['type']} from #{activity['actor']}")
    end
  end
end
