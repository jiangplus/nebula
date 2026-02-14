class ChangeCollectionVisibilityToString < ActiveRecord::Migration[8.1]
  def change
    remove_column :collections, :visibility, :integer
    add_column :collections, :visibility, :string, default: "unlisted", null: false
  end
end
