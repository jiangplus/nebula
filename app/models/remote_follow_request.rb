class RemoteFollowRequest < ApplicationRecord
  self.primary_key = [:remote_user_id, :collection_id]

  belongs_to :remote_user
  belongs_to :collection

  # Composite PK — skip TSID generation
  def set_tsid_id; end
end
