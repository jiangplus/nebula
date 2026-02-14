# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_14_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "access_tokens", primary_key: "token", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.boolean "one_time", default: false, null: false
    t.string "user_id", null: false
    t.index ["user_id"], name: "index_access_tokens_on_user_id"
  end

  create_table "auth_codes", id: :string, force: :cascade do |t|
    t.string "code_type", null: false
    t.datetime "created_at", null: false
    t.string "token", null: false
    t.boolean "used", default: false, null: false
    t.string "user_id", null: false
    t.index ["code_type"], name: "index_auth_codes_on_code_type"
    t.index ["token"], name: "index_auth_codes_on_token", unique: true
    t.index ["user_id"], name: "index_auth_codes_on_user_id"
  end

  create_table "collections", id: :string, force: :cascade do |t|
    t.string "actor_id"
    t.string "alias", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "format"
    t.jsonb "metadata", default: {}, null: false
    t.string "owner_id", null: false
    t.text "post_signature"
    t.text "private_key"
    t.boolean "public", default: false, null: false
    t.boolean "public_owner", default: false, null: false
    t.text "script"
    t.string "shared_inbox_url"
    t.text "style_sheet"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "view_count", default: 0, null: false
    t.string "visibility", default: "unlisted", null: false
    t.index ["actor_id"], name: "index_collections_on_actor_id", unique: true, where: "(actor_id IS NOT NULL)"
    t.index ["alias"], name: "index_collections_on_alias", unique: true
    t.index ["owner_id"], name: "index_collections_on_owner_id"
  end

  create_table "email_subscribers", id: :string, force: :cascade do |t|
    t.boolean "allow_export", default: false, null: false
    t.string "collection_id", null: false
    t.boolean "confirmed", default: false, null: false
    t.string "email"
    t.datetime "subscribed_at", null: false
    t.string "token", null: false
    t.string "user_id"
    t.index ["collection_id"], name: "index_email_subscribers_on_collection_id"
    t.index ["token"], name: "index_email_subscribers_on_token", unique: true
    t.index ["user_id"], name: "index_email_subscribers_on_user_id", where: "(user_id IS NOT NULL)"
  end

  create_table "jobs", id: :string, force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.integer "delay"
    t.string "post_id", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_jobs_on_post_id"
  end

  create_table "oauth_client_states", primary_key: "state", id: :string, force: :cascade do |t|
    t.string "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "provider", null: false
    t.boolean "used", default: false, null: false
  end

  create_table "oauth_users", id: :string, force: :cascade do |t|
    t.string "access_token"
    t.string "client_id", null: false
    t.string "provider", null: false
    t.string "remote_user_id"
    t.string "user_id", null: false
    t.index ["user_id", "provider", "client_id"], name: "index_oauth_users_on_user_id_and_provider_and_client_id", unique: true
    t.index ["user_id"], name: "index_oauth_users_on_user_id"
  end

  create_table "posts", id: :string, force: :cascade do |t|
    t.string "ap_id"
    t.string "collection_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.string "language"
    t.string "modify_token"
    t.string "owner_id", null: false
    t.integer "pinned_position"
    t.integer "privacy", default: 0, null: false
    t.boolean "rtl", default: false, null: false
    t.string "slug"
    t.string "text_appearance", default: "norm"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "view_count", default: 0, null: false
    t.index ["ap_id"], name: "index_posts_on_ap_id", unique: true, where: "(ap_id IS NOT NULL)"
    t.index ["collection_id", "pinned_position"], name: "index_posts_on_collection_id_and_pinned_position", where: "(pinned_position IS NOT NULL)"
    t.index ["collection_id", "slug"], name: "index_posts_on_collection_id_and_slug", unique: true, where: "((collection_id IS NOT NULL) AND (slug IS NOT NULL))"
    t.index ["collection_id"], name: "index_posts_on_collection_id"
    t.index ["owner_id"], name: "index_posts_on_owner_id"
    t.index ["slug"], name: "index_posts_on_slug"
  end

  create_table "remote_follow_requests", primary_key: ["remote_user_id", "collection_id"], force: :cascade do |t|
    t.string "collection_id", null: false
    t.datetime "created_at", null: false
    t.string "remote_user_id", null: false
  end

  create_table "remote_follows", primary_key: ["remote_user_id", "collection_id"], force: :cascade do |t|
    t.string "collection_id", null: false
    t.datetime "created_at", null: false
    t.string "remote_user_id", null: false
  end

  create_table "remote_users", id: :string, force: :cascade do |t|
    t.string "actor_id", null: false
    t.datetime "created_at", null: false
    t.string "handle"
    t.string "inbox"
    t.string "shared_inbox"
    t.index ["actor_id"], name: "index_remote_users_on_actor_id", unique: true
  end

  create_table "user_invites", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.boolean "inactive", default: false, null: false
    t.integer "max_uses"
    t.string "owner_id", null: false
    t.index ["owner_id"], name: "index_user_invites_on_owner_id"
  end

  create_table "users", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "is_admin", default: false, null: false
    t.string "password_digest", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "access_tokens", "users"
  add_foreign_key "auth_codes", "users"
  add_foreign_key "collections", "users", column: "owner_id"
  add_foreign_key "email_subscribers", "collections"
  add_foreign_key "email_subscribers", "users"
  add_foreign_key "jobs", "posts"
  add_foreign_key "oauth_users", "users"
  add_foreign_key "posts", "collections"
  add_foreign_key "posts", "users", column: "owner_id"
  add_foreign_key "remote_follow_requests", "collections"
  add_foreign_key "remote_follow_requests", "remote_users"
  add_foreign_key "remote_follows", "collections"
  add_foreign_key "remote_follows", "remote_users"
  add_foreign_key "user_invites", "users", column: "owner_id"
end
