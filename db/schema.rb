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

ActiveRecord::Schema[8.1].define(version: 2026_04_17_120003) do
  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "cwd"
    t.datetime "file_mtime"
    t.string "file_path", null: false
    t.integer "file_size"
    t.string "git_branch"
    t.datetime "last_activity_at"
    t.integer "message_count", default: 0, null: false
    t.integer "project_id", null: false
    t.string "session_id", null: false
    t.string "slug"
    t.datetime "started_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["file_path"], name: "index_conversations_on_file_path", unique: true
    t.index ["last_activity_at"], name: "index_conversations_on_last_activity_at"
    t.index ["project_id"], name: "index_conversations_on_project_id"
    t.index ["session_id"], name: "index_conversations_on_session_id", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "parent_uuid"
    t.integer "position", null: false
    t.text "raw"
    t.string "record_type", null: false
    t.string "role"
    t.text "text_content"
    t.datetime "timestamp"
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.index ["conversation_id", "position"], name: "index_messages_on_conversation_id_and_position"
    t.index ["conversation_id", "uuid"], name: "index_messages_on_conversation_id_and_uuid"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["record_type"], name: "index_messages_on_record_type"
  end

  create_table "projects", force: :cascade do |t|
    t.integer "conversation_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "last_activity_at"
    t.string "name", null: false
    t.string "path", null: false
    t.datetime "updated_at", null: false
    t.index ["last_activity_at"], name: "index_projects_on_last_activity_at"
    t.index ["path"], name: "index_projects_on_path", unique: true
  end

  add_foreign_key "conversations", "projects"
  add_foreign_key "messages", "conversations"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
