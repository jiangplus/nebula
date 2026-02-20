module ActivityPub
  class FollowersController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_collection

    def show
      followers = {
        "@context": "https://www.w3.org/ns/activitystreams",
        "id": ActivityPub::Urls.followers_url(@collection.alias),
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
  end
end
