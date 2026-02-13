class AccessToken < ApplicationRecord
  self.primary_key = "token"

  belongs_to :user

  before_create :set_token, if: -> { token.blank? }

  private

  def set_token
    self.token = TsidPrimaryKey::TSID_GENERATOR.generate
  end

  # Override default TSID callback since PK is `token`, not `id`
  def set_tsid_id; end
end
