class UserInvite < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :user_invites
end
