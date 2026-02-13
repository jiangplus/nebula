# Implementation Changes from Original Plan

## 1. Removed `collection_passwords` table and feature
- Dropped the `collection_passwords` table from the migration
- Removed the `add_foreign_key :collection_passwords, :collections` foreign key
- Removed `has_one :collection_password, dependent: :destroy` from `Collection` model
- Deleted `app/models/collection_password.rb`

## 2. Replaced `collection_attributes` table with `metadata` JSONB column
- Dropped the `collection_attributes` table (composite PK on `collection_id`, `attribute`) from the migration
- Removed the `add_foreign_key :collection_attributes, :collections` foreign key
- Added `metadata` JSONB column (default `{}`, not null) to the `collections` table
- Removed `has_many :collection_attributes, dependent: :destroy` from `Collection` model
- Deleted `app/models/collection_attribute.rb`

## 3. Removed `collection_redirects` table and feature
- Dropped the `collection_redirects` table (composite PK on `collection_id`, `prev_alias`) from the migration
- Removed the `add_foreign_key :collection_redirects, :collections` foreign key
- Removed `has_many :collection_redirects, dependent: :destroy` from `Collection` model
- Deleted `app/models/collection_redirect.rb`

## 4. Renamed `password_resets` table to `auth_codes` with `code_type` field
- Renamed table from `password_resets` to `auth_codes` in the migration
- Added `code_type` string field to identify types of auth codes (e.g., "password_reset", "email_verification")
- Added index on `code_type` column for querying by type
- Updated foreign key from `add_foreign_key :password_resets, :users` to `add_foreign_key :auth_codes, :users`
- Updated `User` model: changed `has_many :password_resets` to `has_many :auth_codes`
- Deleted `app/models/password_reset.rb` and created `app/models/auth_code.rb`
