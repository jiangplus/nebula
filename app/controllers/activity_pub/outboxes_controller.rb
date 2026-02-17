module ActivityPub
  class OutboxesController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_collection

    def show
      # Only include public posts in the outbox
      public_posts = @collection.posts.where(privacy: 0).order(created_at: :desc).limit(100)

      outbox = {
        "@context": "https://www.w3.org/ns/activitystreams",
        "id": collection_outbox_url(@collection),
        "type": "OrderedCollection",
        "totalItems": public_posts.count,
        "orderedItems": public_posts.map { |post| post_activity(post) }
      }
      render json: outbox
    end

    private

    def set_collection
      @collection = Collection.find_by(alias: params[:collection_alias])
      return head :not_found if @collection.nil?
    end

    def post_activity(post)
      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "type": "Create",
        "id": post_activity_url(post),
        "actor": @collection.actor_id,
        "published": post.created_at.iso8601,
        "to": ["https://www.w3.org/ns/activitystreams#Public"],
        "cc": [api_collection_followers_url(@collection.alias)],
        "object": note_object(post)
      }
    end

    def note_object(post)
      {
        "id": post.ap_id || post_url(post),
        "type": "Note",
        "attributedTo": @collection.actor_id,
        "content": post.content,
        "published": post.created_at.iso8601,
        "url": post_url(post),
        "to": ["https://www.w3.org/ns/activitystreams#Public"],
        "cc": [api_collection_followers_url(@collection.alias)]
      }
    end

    def collection_outbox_url(collection)
      api_collection_outbox_url(collection_alias: collection.alias)
    end

    def post_activity_url(post)
      "#{api_collection_outbox_url(@collection.alias)}##{post.id}/activity"
    end

    def post_url(post)
      if post.collection
        "#{api_collection_url(post.collection.alias)}/#{post.slug}"
      else
        "#{api_collection_url(post.owner.username)}/d/#{post.id}"
      end
    end
  end
end
