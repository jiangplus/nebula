module ActivityPub
  class InboxesController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_collection
    before_action :verify_signature, only: [:create]

    rescue_from JSON::ParserError, with: -> { head :bad_request }

    def show
      head :method_not_allowed
    end

    def create
      activity = JSON.parse(request.body.read)
      return head :bad_request if activity.blank?

      case activity["type"]
      when "Follow"
        handle_follow(activity)
      when "Undo"
        handle_undo(activity)
      when "Like", "Announce"
        handle_engagement(activity)
      when "Delete"
        handle_delete(activity)
      when "Update"
        handle_update(activity)
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

    def verify_signature
      # Skip verification for now - can be enabled later
      # The HTTP signature verification would go here
      # For development/testing, we accept all requests
      true
    end

    def handle_follow(activity)
      actor_id = activity["actor"]
      return if actor_id.blank?

      # Get or create remote user with full actor info
      remote_user = ActivityPub::Service.get_or_create_remote_user(actor_id)
      return if remote_user.nil?

      # Check if already following
      if RemoteFollow.exists?(remote_user: remote_user, collection: @collection)
        # Already following, send Accept anyway
        send_accept(remote_user, activity)
        return
      end

      # Create follow request
      RemoteFollowRequest.find_or_create_by!(
        remote_user: remote_user,
        collection: @collection
      )

      # Auto-accept for now (could be made configurable)
      accept_follow_request(remote_user, activity)
    end

    def accept_follow_request(remote_user, activity)
      # Create the follow relationship
      RemoteFollow.find_or_create_by!(
        remote_user: remote_user,
        collection: @collection
      )

      # Send Accept activity
      send_accept(remote_user, activity)
    end

    def send_accept(remote_user, activity)
      return unless remote_user.inbox.present?
      return unless @collection.private_key.present?

      accept_activity = ActivityPub::Service.build_accept_activity(@collection, activity, remote_user)
      ActivityPub::Service.send_to_inbox(remote_user.inbox, accept_activity, @collection)
    end

    def handle_undo(activity)
      object = activity["object"]
      return if object.blank?

      actor_id = activity["actor"]
      return if actor_id.blank?

      remote_user = RemoteUser.find_by(actor_id: actor_id)
      return if remote_user.nil?

      case object["type"]
      when "Follow"
        RemoteFollow.where(remote_user: remote_user, collection: @collection).destroy_all
        RemoteFollowRequest.where(remote_user: remote_user, collection: @collection).destroy_all
      when "Like"
        # Remove like tracking if we had a likes table
        Rails.logger.info("Undo Like from #{actor_id}")
      when "Announce"
        # Remove announce/boost tracking if we had one
        Rails.logger.info("Undo Announce from #{actor_id}")
      end
    end

    def handle_engagement(activity)
      actor_id = activity["actor"]
      return if actor_id.blank?

      object = activity["object"]
      return if object.blank?

      # Get or update remote user
      remote_user = ActivityPub::Service.get_or_create_remote_user(actor_id)
      return if remote_user.nil?

      case activity["type"]
      when "Like"
        # Store like - would need a remote_likes table
        Rails.logger.info("Like from #{actor_id} on #{object["id"]}")
      when "Announce"
        # Store boost/announce - would need a remote_announces table
        Rails.logger.info("Announce from #{actor_id} on #{object["id"]}")
      end
    end

    def handle_delete(activity)
      object = activity["object"]
      return if object.blank?

      object_id = object["id"]
      return if object_id.blank?

      # Find the post by its AP ID
      post = Post.find_by(ap_id: object_id)
      return unless post

      # Mark as deleted or actually delete
      post.destroy!
      Rails.logger.info("Deleted post #{object_id} via ActivityPub")
    end

    def handle_update(activity)
      object = activity["object"]
      return if object.blank?

      object_id = object["id"]
      return if object_id.blank?

      # For now, just log - full update handling would update the post
      Rails.logger.info("Update received for #{object_id}")
    end
  end
end
