class OauthClientState < ApplicationRecord
  self.primary_key = "state"

  before_create :set_state, if: -> { state.blank? }

  private

  def set_state
    self.state = TsidPrimaryKey::TSID_GENERATOR.generate
  end

  # Override default TSID callback since PK is `state`, not `id`
  def set_tsid_id; end
end
