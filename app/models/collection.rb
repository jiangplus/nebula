class Collection < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :collections

  has_many :posts, dependent: :nullify
  has_many :collection_attributes, dependent: :destroy
  has_many :remote_follows, dependent: :destroy
  has_many :remote_follow_requests, dependent: :destroy
  has_many :email_subscribers, dependent: :destroy
  has_many :collection_redirects, dependent: :destroy
  has_one :collection_password, dependent: :destroy
end
