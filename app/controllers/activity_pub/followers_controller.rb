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
      federation_host = ENV.fetch("FEDERATION_HOST", "localhost:3000")
      api_collection_followers_url(collection.alias, host: federation_host, only_path: false)
    end

    def api_collection_followers_url(alias_, options = {})
      Rails.application.routes.url_helpers.api_collection_followers_url(alias_, **options)
    end
  end
end
