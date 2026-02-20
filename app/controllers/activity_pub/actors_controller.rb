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
      federation_host = ENV.fetch("FEDERATION_HOST", "localhost:3000")
      host_options = { host: federation_host, only_path: false }

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
        "url": actor_url,
        "inbox": api_collection_inbox_url(@collection.alias, host_options),
        "outbox": api_collection_outbox_url(@collection.alias, host_options),
        "followers": api_collection_followers_url(@collection.alias, host_options),
        "following": api_collection_following_url(@collection.alias, host_options),
        "publicKey": {
          "id": "#{actor_url}#main-key",
          "owner": actor_url,
          "publicKeyPem": @collection.public_key
        },
        "endpoints": {
          "sharedInbox": api_collection_inbox_url(@collection.alias, host_options)
        },
        "icon": {
          "type": "Image",
          "mediaType": "image/png",
          "url": "#{request.base_url}/icon.png"
        }
      }
    end

    def actor_url
      federation_host = ENV.fetch("FEDERATION_HOST", "localhost:3000")
      api_collection_url(@collection.alias, host: federation_host, only_path: false)
    end

    def api_collection_url(alias_, options = {})
      Rails.application.routes.url_helpers.api_collection_url(alias_, **options)
    end

    def api_collection_inbox_url(alias_, options = {})
      Rails.application.routes.url_helpers.api_collection_inbox_url(alias_, **options)
    end

    def api_collection_outbox_url(alias_, options = {})
      Rails.application.routes.url_helpers.api_collection_outbox_url(alias_, **options)
    end

    def api_collection_followers_url(alias_, options = {})
      Rails.application.routes.url_helpers.api_collection_followers_url(alias_, **options)
    end

    def api_collection_following_url(alias_, options = {})
      Rails.application.routes.url_helpers.api_collection_following_url(alias_, **options)
    end
  end
end
