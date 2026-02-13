class CreateBaseSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :username, null: false
      t.string :password_digest, null: false
      t.string :email
      t.integer :status, default: 0, null: false
      t.boolean :is_admin, default: false, null: false
      t.timestamps
    end
    add_index :users, :username, unique: true
    add_index :users, :email

    create_table :collections, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :alias, null: false
      t.string :title
      t.text :description
      t.string :owner_id, null: false
      t.boolean :public, default: false, null: false
      t.integer :visibility, default: 0, null: false
      t.integer :view_count, default: 0, null: false
      t.string :format
      t.text :style_sheet
      t.text :script
      t.text :post_signature
      t.boolean :public_owner, default: false, null: false
      t.string :actor_id
      t.string :shared_inbox_url
      t.text :private_key
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end
    add_index :collections, :alias, unique: true
    add_index :collections, :owner_id
    add_index :collections, :actor_id, unique: true, where: "actor_id IS NOT NULL"

    create_table :posts, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :slug
      t.string :title
      t.text :content
      t.string :text_appearance, default: "norm"
      t.string :language
      t.boolean :rtl, default: false, null: false
      t.integer :privacy, default: 0, null: false
      t.string :owner_id, null: false
      t.string :collection_id
      t.integer :view_count, default: 0, null: false
      t.string :modify_token
      t.integer :pinned_position
      t.string :ap_id
      t.timestamps
    end
    add_index :posts, :owner_id
    add_index :posts, :collection_id
    add_index :posts, :slug
    add_index :posts, :ap_id, unique: true, where: "ap_id IS NOT NULL"
    add_index :posts, [:collection_id, :slug], unique: true, where: "collection_id IS NOT NULL AND slug IS NOT NULL"
    add_index :posts, [:collection_id, :pinned_position], where: "pinned_position IS NOT NULL"

    create_table :access_tokens, id: false do |t|
      t.string :token, null: false, primary_key: true
      t.string :user_id, null: false
      t.boolean :one_time, default: false, null: false
      t.datetime :expires_at
      t.datetime :created_at, null: false
    end
    add_index :access_tokens, :user_id

    create_table :email_subscribers, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :collection_id, null: false
      t.string :user_id
      t.string :email
      t.string :token, null: false
      t.boolean :confirmed, default: false, null: false
      t.boolean :allow_export, default: false, null: false
      t.datetime :subscribed_at, null: false
    end
    add_index :email_subscribers, :collection_id
    add_index :email_subscribers, :user_id, where: "user_id IS NOT NULL"
    add_index :email_subscribers, :token, unique: true

    create_table :auth_codes, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :code_type, null: false
      t.string :token, null: false
      t.string :user_id, null: false
      t.boolean :used, default: false, null: false
      t.datetime :created_at, null: false
    end
    add_index :auth_codes, :token, unique: true
    add_index :auth_codes, :user_id
    add_index :auth_codes, :code_type

    create_table :user_invites, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :owner_id, null: false
      t.integer :max_uses
      t.boolean :inactive, default: false, null: false
      t.datetime :expires_at
      t.datetime :created_at, null: false
    end
    add_index :user_invites, :owner_id

    create_table :remote_users, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :actor_id, null: false
      t.string :inbox
      t.string :shared_inbox
      t.string :handle
      t.datetime :created_at, null: false
    end
    add_index :remote_users, :actor_id, unique: true

    create_table :remote_follows, primary_key: [:remote_user_id, :collection_id] do |t|
      t.string :remote_user_id, null: false
      t.string :collection_id, null: false
      t.datetime :created_at, null: false
    end

    create_table :remote_follow_requests, primary_key: [:remote_user_id, :collection_id] do |t|
      t.string :remote_user_id, null: false
      t.string :collection_id, null: false
      t.datetime :created_at, null: false
    end

    create_table :oauth_client_states, id: false do |t|
      t.string :state, null: false, primary_key: true
      t.string :client_id, null: false
      t.string :provider, null: false
      t.boolean :used, default: false, null: false
      t.datetime :expires_at
      t.datetime :created_at, null: false
    end

    create_table :oauth_users, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :user_id, null: false
      t.string :provider, null: false
      t.string :client_id, null: false
      t.string :remote_user_id
      t.string :access_token
    end
    add_index :oauth_users, [:user_id, :provider, :client_id], unique: true
    add_index :oauth_users, :user_id

    create_table :jobs, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :post_id, null: false
      t.string :action, null: false
      t.integer :delay
      t.timestamps
    end
    add_index :jobs, :post_id

    # Foreign keys
    add_foreign_key :collections, :users, column: :owner_id
    add_foreign_key :posts, :users, column: :owner_id
    add_foreign_key :posts, :collections
    add_foreign_key :access_tokens, :users
    add_foreign_key :email_subscribers, :collections
    add_foreign_key :email_subscribers, :users
    add_foreign_key :auth_codes, :users
    add_foreign_key :user_invites, :users, column: :owner_id
    add_foreign_key :remote_follows, :remote_users
    add_foreign_key :remote_follows, :collections
    add_foreign_key :remote_follow_requests, :remote_users
    add_foreign_key :remote_follow_requests, :collections
    add_foreign_key :oauth_users, :users
    add_foreign_key :jobs, :posts
  end
end
