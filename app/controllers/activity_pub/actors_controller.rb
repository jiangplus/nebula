module ActivityPub
  class ActorsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_collection

    def show
      render json: actor_object, content_type: "application/activity+json"
    end

    private

    def set_collection
      @collection = Collection.find_by(alias: params[:collection_alias])
      return head :not_found if @collection.nil?
    end

    def actor_object
      {
        "@context": [
          "https://www.w3.org/ns/activitystreams",
          "https://w3id.org/security/v1"
        ],
        "id": actor_url,
        "type": "Person",
        "preferredUsername": @collection.alias,
        "name": @collection.title,
        "summary": @collection.description,
        "url": collection_url(@collection.alias),
        "inbox": api_collection_inbox_url(@collection.alias),
        "outbox": api_collection_outbox_url(@collection.alias),
        "followers": api_collection_followers_url(@collection.alias),
        "following": api_collection_following_url(@collection.alias),
        "publicKey": {
          "id": "#{actor_url}#main-key",
          "owner": actor_url,
          "publicKeyPem": @collection.public_key
        },
        "endpoints": {
          "sharedInbox": api_collection_inbox_url(@collection.alias)
        },
        "icon": {
          "type": "Image",
          "mediaType": "image/png",
          "url": "#{request.base_url}/icon.png"
        }
      }
    end

    def actor_url
      api_collection_url(@collection.alias)
    end
  end
end
