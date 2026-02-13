module TsidPrimaryKey
  extend ActiveSupport::Concern

  TSID_GENERATOR = Tsid::Generator.new

  included do
    self.primary_key = "id"

    before_create :set_tsid_id, if: -> { id.blank? }
  end

  private

  def set_tsid_id
    self.id = TSID_GENERATOR.generate
  end
end
