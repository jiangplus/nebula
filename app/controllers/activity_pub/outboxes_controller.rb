module ActivityPub
  class OutboxesController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_collection

    def show
      # Only include public posts in the outbox
      public_posts = @collection.posts.where(privacy: 0).order(created_at: :desc).limit(100)

      outbox = {
        "@context": "https://www.w3.org/ns/activitystreams",
        "id": ActivityPub::Urls.outbox_url(@collection.alias),
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
        "id": ActivityPub::Urls.create_activity_id(@collection.alias, post.id),
        "actor": @collection.actor_id,
        "published": post.created_at.iso8601,
        "to": ["https://www.w3.org/ns/activitystreams#Public"],
        "cc": [ActivityPub::Urls.followers_url(@collection.alias)],
        "object": note_object(post)
      }
    end

    def note_object(post)
      {
        "id": ActivityPub::Urls.post_url(post),
        "type": "Note",
        "attributedTo": @collection.actor_id,
        "content": post.content,
        "published": post.created_at.iso8601,
        "url": ActivityPub::Urls.post_url(post),
        "to": ["https://www.w3.org/ns/activitystreams#Public"],
        "cc": [ActivityPub::Urls.followers_url(@collection.alias)]
      }
    end

  end
end
