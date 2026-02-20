class Collection < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :collections

  has_many :posts, dependent: :nullify
  has_many :remote_follows, dependent: :destroy
  has_many :remote_follow_requests, dependent: :destroy
  has_many :email_subscribers, dependent: :destroy

  VISIBILITY_OPTIONS = %w[unlisted private public].freeze

  validates :visibility, inclusion: { in: VISIBILITY_OPTIONS }, if: -> { visibility.present? }
  before_validation :set_default_visibility, on: :create
  before_create :generate_activitypub_keys

  def public?
    visibility == "public"
  end

  def actor_id
    # Generate actor_id if not set using federation host
    return super if super.present?

    federation_host = ENV.fetch("FEDERATION_HOST", "localhost:3000")
    Rails.application.routes.url_helpers.api_collection_url(self.alias, host: federation_host, only_path: false)
  end

  private

  def set_default_visibility
    self.visibility = "unlisted" if visibility.blank?
  end

  def generate_activitypub_keys
    return if private_key.present? || public_key.present?

    # Generate RSA keypair for ActivityPub signing
    key = OpenSSL::PKey::RSA.new(2048)

    self.private_key = key.to_pem
    self.public_key = key.public_key.to_pem

    # Set actor_id based on the collection URL using federation host
    federation_host = ENV.fetch("FEDERATION_HOST", "localhost:3000")
    self.actor_id = Rails.application.routes.url_helpers.api_collection_url(self.alias, host: federation_host, only_path: false)
  end
end
