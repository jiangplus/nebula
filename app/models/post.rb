class Post < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :posts
  belongs_to :collection, optional: true

  has_many :jobs, dependent: :destroy

  after_create :set_ap_id
  after_create :federate_creation
  after_update :federate_update
  after_destroy :federate_deletion

  # Generate AP ID for the post using federation host
  def generate_ap_id
    federation_host = ENV.fetch("FEDERATION_HOST", "localhost:3000")

    if collection
      path = id
      "#{Rails.application.routes.url_helpers.api_collection_url(collection.alias, host: federation_host, only_path: false)}/#{path}"
    else
      Rails.application.routes.url_helpers.draft_post_url(self, host: federation_host, only_path: false)
    end
  end

  private

  def set_ap_id
    return if self.ap_id.present?

    update_column(:ap_id, generate_ap_id)
  end

  def federate_creation
    return unless collection&.present?
    return unless collection.remote_follows.any?
    return unless collection.private_key.present?

    # Set the AP ID before federating
    update_column(:ap_id, generate_ap_id)

    # Federate in background
    ActivityPub::Service.federate_post(collection, self, action: :create)
  end

  def federate_update
    return unless collection&.present?
    return unless collection.remote_follows.any?
    return unless collection.private_key.present?
    return unless saved_change_to_content? || saved_change_to_title?

    # Ensure AP ID is set
    update_column(:ap_id, generate_ap_id)

    ActivityPub::Service.federate_post(collection, self, action: :update)
  end

  def federate_deletion
    return unless collection&.present?
    return unless collection.remote_follows.any?
    return unless collection.private_key.present?

    ActivityPub::Service.federate_post(collection, self, action: :delete)
  end
end
