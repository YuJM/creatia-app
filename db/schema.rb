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

ActiveRecord::Schema[8.0].define(version: 2025_08_30_011553) do
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
    t.index ["active"], name: "index_organization_memberships_on_active"
    t.index ["organization_id"], name: "index_organization_memberships_on_organization_id"
    t.index ["role"], name: "index_organization_memberships_on_role"
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

  create_table "pomodoro_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "task_id", null: false
    t.uuid "user_id", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "session_count"
    t.integer "duration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "ended_at"
    t.integer "actual_duration"
    t.datetime "paused_at"
    t.integer "paused_duration", default: 0
    t.integer "status", default: 0, null: false
    t.index ["status"], name: "index_pomodoro_sessions_on_status"
    t.index ["task_id"], name: "index_pomodoro_sessions_on_task_id"
    t.index ["user_id"], name: "index_pomodoro_sessions_on_user_id"
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

  create_table "sprints", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "service_id", null: false
    t.string "name"
    t.date "start_date"
    t.date "end_date"
    t.text "goal"
    t.text "schedule"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0, null: false
    t.time "start_time", default: "2000-01-01 09:00:00"
    t.time "end_time", default: "2000-01-01 18:00:00"
    t.boolean "flexible_hours", default: false
    t.boolean "weekend_work", default: false
    t.time "daily_standup_time"
    t.datetime "review_meeting_time"
    t.datetime "retrospective_time"
    t.jsonb "custom_schedule"
    t.index ["service_id"], name: "index_sprints_on_service_id"
    t.index ["status"], name: "index_sprints_on_status"
  end

  create_table "tasks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "status"
    t.string "priority"
    t.uuid "organization_id", null: false
    t.string "assigned_user_type"
    t.uuid "assigned_user_id"
    t.datetime "due_date"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.decimal "estimated_hours", precision: 10, scale: 2
    t.decimal "actual_hours", precision: 10, scale: 2
    t.datetime "deadline"
    t.integer "story_points"
    t.uuid "sprint_id"
    t.uuid "team_id"
    t.uuid "service_id"
    t.uuid "assignee_id"
    t.uuid "created_by_id"
    t.index ["assigned_user_type", "assigned_user_id"], name: "index_tasks_on_assigned_user"
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["completed_at"], name: "index_tasks_on_completed_at"
    t.index ["created_by_id"], name: "index_tasks_on_created_by_id"
    t.index ["deadline", "completed_at"], name: "index_tasks_on_deadline_and_completed"
    t.index ["deadline"], name: "index_tasks_on_deadline"
    t.index ["organization_id", "assigned_user_id", "assigned_user_type"], name: "idx_on_organization_id_assigned_user_id_assigned_us_0cf40f5b5d"
    t.index ["organization_id", "deadline"], name: "index_tasks_on_org_and_deadline"
    t.index ["organization_id", "priority"], name: "index_tasks_on_organization_id_and_priority"
    t.index ["organization_id", "status"], name: "index_tasks_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_tasks_on_organization_id"
    t.index ["position"], name: "index_tasks_on_position"
    t.index ["service_id"], name: "index_tasks_on_service_id"
    t.index ["sprint_id"], name: "index_tasks_on_sprint_id"
    t.index ["started_at"], name: "index_tasks_on_started_at"
    t.index ["team_id"], name: "index_tasks_on_team_id"
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
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "pomodoro_sessions", "tasks"
  add_foreign_key "pomodoro_sessions", "users"
  add_foreign_key "services", "organizations"
  add_foreign_key "sprints", "services"
  add_foreign_key "tasks", "organizations"
  add_foreign_key "tasks", "services"
  add_foreign_key "tasks", "sprints"
  add_foreign_key "tasks", "teams"
  add_foreign_key "tasks", "users", column: "assignee_id"
  add_foreign_key "tasks", "users", column: "created_by_id"
  add_foreign_key "team_members", "teams"
  add_foreign_key "team_members", "users"
  add_foreign_key "teams", "organizations"
end
