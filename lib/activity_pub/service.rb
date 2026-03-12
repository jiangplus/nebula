# Service for ActivityPub operations like fetching remote actors and sending activities
require "net/http"
require "json"
require "base64"
require "digest"
require "openssl"

module ActivityPub
  class Service
    # Fetch a remote actor by URL
    def self.fetch_actor(actor_url)
      return nil unless actor_url.start_with?("http")

      uri = URI.parse(actor_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Accept"] = "application/activity+json"

      begin
        response = http.request(request)
        return nil unless response.code == "200"

        JSON.parse(response.body)
      rescue => e
        Rails.logger.error("Failed to fetch actor: #{e.message}")
        nil
      end
    end

    # Get or create a RemoteUser from an actor URL
    def self.get_or_create_remote_user(actor_url)
      actor = fetch_actor(actor_url)
      return nil unless actor

      # Parse actor to get inbox and handle
      inbox = actor["inbox"]
      shared_inbox = actor["endpoints"]&.[]("sharedInbox") || inbox
      handle = actor["preferredUsername"]
      # Also try to get a display name or fallback to the actor URL
      handle ||= actor["name"] || actor_url

      # Find or create the remote user
      remote_user = RemoteUser.find_or_create_by(actor_id: actor_url) do |user|
        user.inbox = inbox
        user.shared_inbox = shared_inbox
        user.handle = handle
      end

      # Update if changed
      if remote_user.inbox != inbox || remote_user.shared_inbox != shared_inbox
        remote_user.update!(inbox: inbox, shared_inbox: shared_inbox, handle: handle)
      end

      remote_user
    end

    # Send an activity to a remote inbox
    def self.send_to_inbox(inbox_url, activity, collection)
      return unless inbox_url.present?
      return unless collection.private_key.present?

      uri = URI.parse(inbox_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/activity+json"
      request["Accept"] = "application/activity+json"
      request["Date"] = Time.now.utc.httpdate

      # Add digest
      body = activity.to_json
      digest = "SHA-256=#{Base64.strict_encode64(Digest::SHA256.digest(body))}"
      request["Digest"] = digest
      request.body = body

      # Sign the request with RSA-SHA256 HTTP Signature
      key_id      = "#{collection.actor_id}#main-key"
      host        = "#{uri.host}:#{uri.port}"
      target      = "post #{uri.request_uri}"
      signed_str  = "(request-target): #{target}\nhost: #{host}\ndate: #{request['Date']}\ndigest: #{digest}"
      rsa_key     = OpenSSL::PKey::RSA.new(collection.private_key)
      sig_b64     = Base64.strict_encode64(rsa_key.sign(OpenSSL::Digest::SHA256.new, signed_str))
      request["Signature"] = %(keyId="#{key_id}",algorithm="rsa-sha256",headers="(request-target) host date digest",signature="#{sig_b64}")

      begin
        response = http.request(request)
        Rails.logger.info("ActivityPub: Sent to #{inbox_url}, status: #{response.code}")
        response.code == "200" || response.code == "202"
      rescue => e
        Rails.logger.error("ActivityPub: Failed to send to #{inbox_url}: #{e.message}")
        false
      end
    end

    # Federate a post to all followers
    def self.federate_post(collection, post, action: :create)
      return unless collection.present?

      # Get all followers
      followers = collection.remote_follows.includes(:remote_user)

      # Group by shared inbox for optimization
      by_shared_inbox = followers.group_by do |follow|
        follow.remote_user.shared_inbox
      end

      by_shared_inbox.each do |shared_inbox, follows|
        next unless shared_inbox

        # Build the activity
        activity = case action
                   when :create
                     build_create_activity(collection, post)
                   when :update
                     build_update_activity(collection, post)
                   when :delete
                     build_delete_activity(collection, post)
                   else
                     return
                   end

        # Send to shared inbox
        send_to_inbox(shared_inbox, activity, collection)
      end

      # Also handle mentions - send to individual inboxes
      # This would require parsing post content for @mentions
    end

    # Build a Create activity for a post
    def self.build_create_activity(collection, post)
      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "type": "Create",
        "id": Urls.create_activity_id(collection.alias, post.id),
        "actor": collection.actor_id,
        "published": post.created_at.iso8601,
        "to": ["https://www.w3.org/ns/activitystreams#Public"],
        "cc": [Urls.followers_url(collection.alias)],
        "object": build_note_object(collection, post)
      }
    end

    # Build an Update activity for a post
    def self.build_update_activity(collection, post)
      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "type": "Update",
        "id": Urls.update_activity_id(collection.alias, post.id),
        "actor": collection.actor_id,
        "published": post.updated_at.iso8601,
        "to": ["https://www.w3.org/ns/activitystreams#Public"],
        "cc": [Urls.followers_url(collection.alias)],
        "object": build_note_object(collection, post)
      }
    end

    # Build a Delete activity for a post
    def self.build_delete_activity(collection, post)
      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "type": "Delete",
        "id": Urls.delete_activity_id(collection.alias, post.id),
        "actor": collection.actor_id,
        "published": Time.now.utc.iso8601,
        "to": ["https://www.w3.org/ns/activitystreams#Public"],
        "cc": [Urls.followers_url(collection.alias)],
        "object": {
          "id": Urls.post_url(post),
          "type": "Tombstone"
        }
      }
    end

    # Build an Accept activity for a follow request
    def self.build_accept_activity(collection, follow_activity, remote_user)
      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "type": "Accept",
        "id": Urls.accept_activity_id(collection.actor_id, remote_user.actor_id),
        "actor": collection.actor_id,
        "to": [remote_user.actor_id],
        "object": {
          "type": "Follow",
          "id": follow_activity["id"],
          "actor": remote_user.actor_id,
          "object": collection.actor_id
        }
      }
    end

    # Build a Note object from a post
    def self.build_note_object(collection, post)
      {
        "id": Urls.post_url(post),
        "type": "Note",
        "attributedTo": collection.actor_id,
        "content": post.content,
        "published": post.created_at.iso8601,
        "url": Urls.post_url(post),
        "to": ["https://www.w3.org/ns/activitystreams#Public"],
        "cc": [Urls.followers_url(collection.alias)]
      }
    end

  end
end
