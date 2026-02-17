module ActivityPub
  class FollowingController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_collection

    def show
      # Nebula doesn't track who we follow yet - this is a placeholder
      # In the future, we would have a remote_following table
      following = {
        "@context": "https://www.w3.org/ns/activitystreams",
        "id": collection_following_url(@collection),
        "type": "OrderedCollection",
        "totalItems": 0,
        "orderedItems": []
      }
      render json: following
    end

    private

    def set_collection
      @collection = Collection.find_by(alias: params[:collection_alias])
      return head :not_found if @collection.nil?
    end

    def collection_following_url(collection)
      api_collection_following_url(collection_alias: collection.alias)
    end
  end
end
