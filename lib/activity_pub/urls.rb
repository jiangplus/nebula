module ActivityPub
  module Urls
    AS_PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

    def self.federation_host
      ENV.fetch("FEDERATION_HOST", "localhost:3000")
    end

    def self.federation_domain
      federation_host.split(":").first
    end

    # Actor-level URLs
    def self.actor_url(collection_alias)
      helpers.api_collection_url(collection_alias, **host_options)
    end

    def self.inbox_url(collection_alias)
      helpers.api_collection_inbox_url(collection_alias, **host_options)
    end

    def self.outbox_url(collection_alias)
      helpers.api_collection_outbox_url(collection_alias, **host_options)
    end

    def self.followers_url(collection_alias)
      helpers.api_collection_followers_url(collection_alias, **host_options)
    end

    def self.following_url(collection_alias)
      helpers.api_collection_following_url(collection_alias, **host_options)
    end

    # Key fragment
    def self.public_key_id(collection_alias)
      "#{actor_url(collection_alias)}#main-key"
    end

    # Post URL (canonical — single implementation, fixes current inconsistencies)
    # Uses post.ap_id if already set; otherwise:
    #   - collection post: api_collection_url(alias)/slug  (fallback to id if no slug)
    #   - draft post:      draft_post_url(post)
    def self.post_url(post)
      return post.ap_id if post.ap_id.present?

      if post.collection_id.present?
        collection = post.collection
        path = post.slug.presence || post.id
        helpers.api_collection_url(collection.alias, path, **host_options)
      else
        helpers.draft_post_url(post, **host_options)
      end
    end

    # Activity id URLs (fragment-based, not stored)
    def self.create_activity_id(collection_alias, post_id)
      "#{outbox_url(collection_alias)}##{post_id}/create"
    end

    def self.update_activity_id(collection_alias, post_id)
      "#{outbox_url(collection_alias)}##{post_id}/update"
    end

    def self.delete_activity_id(collection_alias, post_id)
      "#{outbox_url(collection_alias)}##{post_id}/delete"
    end

    def self.accept_activity_id(actor_id, remote_actor_id)
      "#{actor_id}#accepts/#{remote_actor_id}/#{Time.now.to_i}"
    end

    def self.host_options
      { host: federation_host, only_path: false }
    end

    def self.helpers
      Rails.application.routes.url_helpers
    end

    private_class_method :host_options, :helpers
  end
end
