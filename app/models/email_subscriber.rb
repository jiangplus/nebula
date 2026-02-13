class EmailSubscriber < ApplicationRecord
  belongs_to :collection
  belongs_to :user, optional: true
end
