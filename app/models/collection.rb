class Collection < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :collections

  has_many :posts, dependent: :nullify
  has_many :remote_follows, dependent: :destroy
  has_many :remote_follow_requests, dependent: :destroy
  has_many :email_subscribers, dependent: :destroy
end
