module ActivityPub
  module Webfinger
    class ShowController < ApplicationController
      skip_before_action :verify_authenticity_token

      def show
        resource = params[:resource]
        return head :bad_request if resource.blank?

        # Parse acct:user@host format
        if resource.start_with?("acct:")
          _, account = resource.split(":", 2)
          username, host = account.split("@", 2)

          # Check if this is our host
          if host == request.host
            collection = Collection.find_by(alias: username)
            if collection
              render json: {
                "subject" => resource,
                "aliases" => [collection_url(username)],
                "links" => [
                  {
                    "rel" => "self",
                    "type" => "application/activity+json",
                    "href" => api_collection_actor_url(username)
                  }
                ]
              }
              return
            end
          end
        end

        head :not_found
      end
    end
  end
end
