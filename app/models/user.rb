class User < ApplicationRecord
  has_many :collections, foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :posts, foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :access_tokens, dependent: :destroy
  has_many :oauth_users, dependent: :destroy
  has_many :password_resets, dependent: :destroy
  has_many :user_invites, foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :email_subscribers, dependent: :nullify
end
