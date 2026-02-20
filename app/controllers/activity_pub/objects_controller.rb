module ActivityPub
  class ObjectsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_post

    def show
      render json: note_object, content_type: "application/activity+json"
    end

    private

    def set_post
      # Try to find by slug in a collection
      if params[:collection_alias] && params[:slug]
        collection = Collection.find_by(alias: params[:collection_alias])
        @post = Post.find_by(collection: collection, slug: params[:slug]) if collection
      end

      # Try to find by AP ID
      if @post.nil? && params[:ap_id]
        @post = Post.find_by(ap_id: params[:ap_id])
      end

      return head :not_found if @post.nil?
    end

    def note_object
      post = @post
      collection = post.collection

      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "id": ActivityPub::Urls.post_url(post),
        "type": "Note",
        "attributedTo": collection ? collection.actor_id : post.owner.username,
        "content": post.content,
        "published": post.created_at.iso8601,
        "url": ActivityPub::Urls.post_url(post),
        "to": ["https://www.w3.org/ns/activitystreams#Public"]
      }
    end
  end
end
