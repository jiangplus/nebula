class RemoteUser < ApplicationRecord
  has_many :remote_follows, dependent: :destroy
  has_many :remote_follow_requests, dependent: :destroy
end
