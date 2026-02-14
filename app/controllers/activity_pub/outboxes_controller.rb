module ActivityPub
  class OutboxesController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_collection

    def show
      outbox = {
        "@context": "https://www.w3.org/ns/activitystreams",
        "id": collection_outbox_url(@collection),
        "type": "OrderedCollection",
        "totalItems": @collection.posts.count,
        "orderedItems": @collection.posts.map { |post| post_activity(post) }
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
        "object": {
          "type": "Note",
          "id": post_url(post),
          "attributedTo": @collection.actor_id,
          "content": post.content,
          "published": post.created_at.iso8601
        }
      }
    end

    def collection_outbox_url(collection)
      api_collection_outbox_url(collection_alias: collection.alias)
    end

    def post_activity_url(post)
      "#{api_collection_outbox_url(collection_alias: post.collection.alias)}##{post.id}"
    end

    def post_url(post)
      if post.collection
        collection_post_url(collection_alias: post.collection.alias, slug: post.slug)
      else
        draft_post_url(post)
      end
    end
  end
end
