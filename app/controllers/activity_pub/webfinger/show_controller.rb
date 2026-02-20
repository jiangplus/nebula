module ActivityPub
  module Webfinger
    class ShowController < ApplicationController
      skip_before_action :verify_authenticity_token

      def show
        resource = params[:resource]
        return head :bad_request if resource.blank?

        federation_host = ActivityPub::Urls.federation_host
        federation_domain = ActivityPub::Urls.federation_domain

        # Parse acct:user@host format
        if resource.start_with?("acct:")
          _, account = resource.split(":", 2)
          username, host = account.split("@", 2)

          # Check if this is our host (match both with and without port)
          if host == federation_host || host == federation_domain
            collection = Collection.find_by(alias: username)
            if collection
              render json: {
                "subject" => resource,
                "aliases" => [ActivityPub::Urls.actor_url(username)],
                "links" => [
                  {
                    "rel" => "self",
                    "type" => "application/activity+json",
                    "href" => ActivityPub::Urls.actor_url(username)
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
