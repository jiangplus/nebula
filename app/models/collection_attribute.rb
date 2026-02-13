class CollectionAttribute < ApplicationRecord
  self.primary_key = [:collection_id, :attribute]

  belongs_to :collection

  # Composite PK — skip TSID generation
  def set_tsid_id; end
end
