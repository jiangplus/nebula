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

ActiveRecord::Schema[8.1].define(version: 2026_02_14_080230) do
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

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "callback_priority"
    t.text "callback_queue_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.text "on_discard"
    t.text "on_finish"
    t.text "on_success"
    t.jsonb "serialized_properties"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id", null: false
    t.datetime "created_at", null: false
    t.interval "duration"
    t.text "error"
    t.text "error_backtrace", array: true
    t.integer "error_event", limit: 2
    t.datetime "finished_at"
    t.text "job_class"
    t.uuid "process_id"
    t.text "queue_name"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_type", limit: 2
    t.jsonb "state"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "key"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id"
    t.uuid "batch_callback_id"
    t.uuid "batch_id"
    t.text "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "cron_at"
    t.text "cron_key"
    t.text "error"
    t.integer "error_event", limit: 2
    t.integer "executions_count"
    t.datetime "finished_at"
    t.boolean "is_discrete"
    t.text "job_class"
    t.text "labels", array: true
    t.datetime "locked_at"
    t.uuid "locked_by_id"
    t.datetime "performed_at"
    t.integer "priority"
    t.text "queue_name"
    t.uuid "retried_good_job_id"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
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
