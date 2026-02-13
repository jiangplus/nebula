class Post < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :posts
  belongs_to :collection, optional: true

  has_many :jobs, dependent: :destroy
end
