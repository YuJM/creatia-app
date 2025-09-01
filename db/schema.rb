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

ActiveRecord::Schema[8.0].define(version: 2025_09_01_153048) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "organization_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "organization_id", null: false
    t.string "role", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "role_id"
    t.index ["active"], name: "index_organization_memberships_on_active"
    t.index ["organization_id"], name: "index_organization_memberships_on_organization_id"
    t.index ["role"], name: "index_organization_memberships_on_role"
    t.index ["role_id"], name: "index_organization_memberships_on_role_id"
    t.index ["user_id", "organization_id"], name: "index_org_memberships_on_user_and_org", unique: true
    t.index ["user_id"], name: "index_organization_memberships_on_user_id"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "subdomain"
    t.text "description"
    t.string "plan"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subdomain"], name: "index_organizations_on_subdomain", unique: true
  end

  create_table "permission_audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "organization_id", null: false
    t.string "action", null: false
    t.string "resource_type"
    t.uuid "resource_id"
    t.boolean "permitted"
    t.jsonb "context", default: {}
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_permission_audit_logs_on_created_at"
    t.index ["organization_id"], name: "index_permission_audit_logs_on_organization_id"
    t.index ["permitted"], name: "index_permission_audit_logs_on_permitted"
    t.index ["resource_type", "resource_id"], name: "index_permission_audit_logs_on_resource_type_and_resource_id"
    t.index ["user_id", "organization_id"], name: "index_permission_audit_logs_on_user_id_and_organization_id"
    t.index ["user_id"], name: "index_permission_audit_logs_on_user_id"
  end

  create_table "permission_delegations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "delegator_id", null: false
    t.uuid "delegatee_id", null: false
    t.uuid "organization_id", null: false
    t.uuid "role_id"
    t.jsonb "permissions", default: []
    t.datetime "starts_at", null: false
    t.datetime "expires_at", null: false
    t.boolean "active", default: true
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_permission_delegations_on_active"
    t.index ["delegatee_id"], name: "index_permission_delegations_on_delegatee_id"
    t.index ["delegator_id", "delegatee_id", "organization_id"], name: "idx_delegations_on_users_org"
    t.index ["delegator_id"], name: "index_permission_delegations_on_delegator_id"
    t.index ["organization_id"], name: "index_permission_delegations_on_organization_id"
    t.index ["role_id"], name: "index_permission_delegations_on_role_id"
    t.index ["starts_at", "expires_at"], name: "index_permission_delegations_on_starts_at_and_expires_at"
  end

  create_table "permission_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "key", null: false
    t.text "description"
    t.jsonb "permissions", default: []
    t.boolean "system_template", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permission_templates_on_key", unique: true
  end

  create_table "permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "resource", null: false
    t.string "action", null: false
    t.string "name", null: false
    t.text "description"
    t.string "category"
    t.boolean "system_permission", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_permissions_on_category"
    t.index ["resource", "action"], name: "index_permissions_on_resource_and_action", unique: true
  end

  create_table "resource_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "organization_id", null: false
    t.string "resource_type", null: false
    t.uuid "resource_id", null: false
    t.uuid "permission_id", null: false
    t.boolean "granted", default: true
    t.datetime "expires_at"
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_resource_permissions_on_expires_at"
    t.index ["organization_id"], name: "index_resource_permissions_on_organization_id"
    t.index ["permission_id"], name: "index_resource_permissions_on_permission_id"
    t.index ["resource_type", "resource_id"], name: "index_resource_permissions_on_resource_type_and_resource_id"
    t.index ["user_id", "organization_id", "resource_type", "resource_id"], name: "idx_resource_perms_on_user_org_resource"
    t.index ["user_id"], name: "index_resource_permissions_on_user_id"
  end

  create_table "role_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "role_id", null: false
    t.uuid "permission_id", null: false
    t.jsonb "conditions", default: {}
    t.jsonb "scope", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "name", null: false
    t.string "key", null: false
    t.text "description"
    t.boolean "system_role", default: false
    t.boolean "editable", default: true
    t.integer "priority", default: 0
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "key"], name: "index_roles_on_organization_id_and_key", unique: true
    t.index ["organization_id"], name: "index_roles_on_organization_id"
    t.index ["priority"], name: "index_roles_on_priority"
    t.index ["system_role"], name: "index_roles_on_system_role"
  end

  create_table "services", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "name"
    t.string "key"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "task_prefix"
    t.index ["organization_id"], name: "index_services_on_organization_id"
  end

  create_table "team_members", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "team_id", null: false
    t.uuid "user_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "user_id"], name: "index_team_members_on_team_id_and_user_id", unique: true
    t.index ["team_id"], name: "index_team_members_on_team_id"
    t.index ["user_id"], name: "index_team_members_on_user_id"
  end

  create_table "teams", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "lead_id"
    t.index ["lead_id"], name: "index_teams_on_lead_id"
    t.index ["organization_id"], name: "index_teams_on_organization_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "username"
    t.string "avatar_url"
    t.text "bio"
    t.string "role", default: "user"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "roles"
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "permission_audit_logs", "organizations"
  add_foreign_key "permission_audit_logs", "users"
  add_foreign_key "permission_delegations", "organizations"
  add_foreign_key "permission_delegations", "roles"
  add_foreign_key "permission_delegations", "users", column: "delegatee_id"
  add_foreign_key "permission_delegations", "users", column: "delegator_id"
  add_foreign_key "resource_permissions", "organizations"
  add_foreign_key "resource_permissions", "permissions"
  add_foreign_key "resource_permissions", "users"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "roles", "organizations"
  add_foreign_key "services", "organizations"
  add_foreign_key "team_members", "teams"
  add_foreign_key "team_members", "users"
  add_foreign_key "teams", "organizations"
end
