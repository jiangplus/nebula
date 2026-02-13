class CollectionPassword < ApplicationRecord
  self.primary_key = "collection_id"

  belongs_to :collection

  # PK is the FK — skip TSID generation
  def set_tsid_id; end
end
