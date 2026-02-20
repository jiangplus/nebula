class AddPublicKeyToCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :collections, :public_key, :text
  end
end
