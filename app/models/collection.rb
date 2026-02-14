class Collection < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :collections

  has_many :posts, dependent: :nullify
  has_many :remote_follows, dependent: :destroy
  has_many :remote_follow_requests, dependent: :destroy
  has_many :email_subscribers, dependent: :destroy

  VISIBILITY_OPTIONS = %w[unlisted private public].freeze

  validates :visibility, inclusion: { in: VISIBILITY_OPTIONS }, if: -> { visibility.present? }
  before_validation :set_default_visibility, on: :create

  def public?
    visibility == "public"
  end

  private

  def set_default_visibility
    self.visibility = "unlisted" if visibility.blank?
  end
end
