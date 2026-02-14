module ActivityPub
  class FollowersController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_collection

    def show
      followers = {
        "@context": "https://www.w3.org/ns/activitystreams",
        "id": collection_followers_url(@collection),
        "type": "OrderedCollection",
        "totalItems": @collection.remote_follows.count,
        "orderedItems": @collection.remote_follows.map { |follow| follow.remote_user.actor_id }
      }
      render json: followers
    end

    private

    def set_collection
      @collection = Collection.find_by(alias: params[:collection_alias])
      return head :not_found if @collection.nil?
    end

    def collection_followers_url(collection)
      api_collection_followers_url(collection_alias: collection.alias)
    end
  end
end
