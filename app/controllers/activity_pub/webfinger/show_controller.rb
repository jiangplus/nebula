module ActivityPub
  module Webfinger
    class ShowController < ApplicationController
      skip_before_action :verify_authenticity_token

      def show
        resource = params[:resource]
        return head :bad_request if resource.blank?

        federation_host = ENV.fetch("FEDERATION_HOST", "localhost:3000")
        federation_domain = federation_host.split(":").first  # Extract just the domain part

        # Parse acct:user@host format
        if resource.start_with?("acct:")
          _, account = resource.split(":", 2)
          username, host = account.split("@", 2)

          # Check if this is our host
          if host == federation_domain
            collection = Collection.find_by(alias: username)
            if collection
              host_options = { host: federation_host, only_path: false }
              render json: {
                "subject" => resource,
                "aliases" => [api_collection_url(username, host_options)],
                "links" => [
                  {
                    "rel" => "self",
                    "type" => "application/activity+json",
                    "href" => api_collection_actor_url(username, host_options)
                  }
                ]
              }
              return
            end
          end
        end

        head :not_found
      end

      private

      def api_collection_url(alias_, options = {})
        Rails.application.routes.url_helpers.api_collection_url(alias_, **options)
      end

      def api_collection_actor_url(alias_, options = {})
        Rails.application.routes.url_helpers.api_collection_actor_url(alias_, **options)
      end
    end
  end
end
