class User < ApplicationRecord
  has_secure_password

  has_many :collections, foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :posts, foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :access_tokens, dependent: :destroy
  has_many :oauth_users, dependent: :destroy
  has_many :auth_codes, dependent: :destroy
  has_many :user_invites, foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :email_subscribers, dependent: :nullify

  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }, if: -> { password.present? }
end
