class Post < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :posts
  belongs_to :collection, optional: true

  has_many :jobs, dependent: :destroy

  after_create :federate_creation
  after_update :federate_update
  after_destroy :federate_deletion

  # Generate AP ID for the post
  def ap_id
    return super if super.present?

    if collection
      "#{Rails.application.routes.url_helpers.api_collection_url(collection.alias)}/#{slug}"
    else
      "#{Rails.application.routes.url_helpers.draft_post_url(self)}"
    end
  end

  private

  def federate_creation
    return unless collection&.present?
    return unless collection.remote_follows.any?
    return unless collection.private_key.present?

    # Set the AP ID before federating
    update_column(:ap_id, ap_id) if ap_id.present?

    # Federate in background
    ActivityPub::Service.federate_post(collection, self, action: :create)
  end

  def federate_update
    return unless collection&.present?
    return unless collection.remote_follows.any?
    return unless collection.private_key.present?
    return unless saved_change_to_content? || saved_change_to_title?

    # Ensure AP ID is set
    update_column(:ap_id, ap_id) if ap_id.present?

    ActivityPub::Service.federate_post(collection, self, action: :update)
  end

  def federate_deletion
    return unless collection&.present?
    return unless collection.remote_follows.any?
    return unless collection.private_key.present?

    ActivityPub::Service.federate_post(collection, self, action: :delete)
  end
end
