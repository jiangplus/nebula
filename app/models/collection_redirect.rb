class CollectionRedirect < ApplicationRecord
  self.primary_key = [:collection_id, :prev_alias]

  belongs_to :collection

  # Composite PK — skip TSID generation
  def set_tsid_id; end
end
