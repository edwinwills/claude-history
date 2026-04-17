CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "projects" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "path" varchar NOT NULL, "name" varchar NOT NULL, "last_activity_at" datetime(6), "conversation_count" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_projects_on_path" ON "projects" ("path") /*application='ClaudeHistory'*/;
CREATE INDEX "index_projects_on_last_activity_at" ON "projects" ("last_activity_at") /*application='ClaudeHistory'*/;
CREATE TABLE IF NOT EXISTS "conversations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "project_id" integer NOT NULL, "session_id" varchar NOT NULL, "file_path" varchar NOT NULL, "file_mtime" datetime(6), "file_size" integer, "slug" varchar, "title" varchar, "started_at" datetime(6), "last_activity_at" datetime(6), "message_count" integer DEFAULT 0 NOT NULL, "git_branch" varchar, "cwd" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "custom_title" varchar /*application='ClaudeHistory'*/, CONSTRAINT "fk_rails_57f4adaad9"
FOREIGN KEY ("project_id")
  REFERENCES "projects" ("id")
);
CREATE INDEX "index_conversations_on_project_id" ON "conversations" ("project_id") /*application='ClaudeHistory'*/;
CREATE UNIQUE INDEX "index_conversations_on_session_id" ON "conversations" ("session_id") /*application='ClaudeHistory'*/;
CREATE UNIQUE INDEX "index_conversations_on_file_path" ON "conversations" ("file_path") /*application='ClaudeHistory'*/;
CREATE INDEX "index_conversations_on_last_activity_at" ON "conversations" ("last_activity_at") /*application='ClaudeHistory'*/;
CREATE TABLE IF NOT EXISTS "messages" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "conversation_id" integer NOT NULL, "uuid" varchar, "parent_uuid" varchar, "record_type" varchar NOT NULL, "role" varchar, "text_content" text, "raw" text, "timestamp" datetime(6), "position" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_7f927086d2"
FOREIGN KEY ("conversation_id")
  REFERENCES "conversations" ("id")
);
CREATE INDEX "index_messages_on_conversation_id" ON "messages" ("conversation_id") /*application='ClaudeHistory'*/;
CREATE INDEX "index_messages_on_conversation_id_and_position" ON "messages" ("conversation_id", "position") /*application='ClaudeHistory'*/;
CREATE INDEX "index_messages_on_conversation_id_and_uuid" ON "messages" ("conversation_id", "uuid") /*application='ClaudeHistory'*/;
CREATE INDEX "index_messages_on_record_type" ON "messages" ("record_type") /*application='ClaudeHistory'*/;
CREATE VIRTUAL TABLE messages_fts USING fts5(
  text_content,
  content='messages',
  content_rowid='id',
  tokenize='porter unicode61'
)
/* messages_fts(text_content) */;
CREATE TABLE IF NOT EXISTS 'messages_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'messages_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'messages_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'messages_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TRIGGER messages_ai AFTER INSERT ON messages BEGIN
  INSERT INTO messages_fts(rowid, text_content) VALUES (new.id, new.text_content);
END;
CREATE TRIGGER messages_ad AFTER DELETE ON messages BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, text_content) VALUES('delete', old.id, old.text_content);
END;
CREATE TRIGGER messages_au AFTER UPDATE ON messages BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, text_content) VALUES('delete', old.id, old.text_content);
  INSERT INTO messages_fts(rowid, text_content) VALUES (new.id, new.text_content);
END;
CREATE TABLE IF NOT EXISTS "labels" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_labels_on_lower_name" ON "labels" (LOWER(name)) /*application='ClaudeHistory'*/;
CREATE TABLE IF NOT EXISTS "conversation_labels" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "conversation_id" integer NOT NULL, "label_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_97fe12b0fc"
FOREIGN KEY ("conversation_id")
  REFERENCES "conversations" ("id")
, CONSTRAINT "fk_rails_1780e2a8dd"
FOREIGN KEY ("label_id")
  REFERENCES "labels" ("id")
);
CREATE INDEX "index_conversation_labels_on_conversation_id" ON "conversation_labels" ("conversation_id") /*application='ClaudeHistory'*/;
CREATE INDEX "index_conversation_labels_on_label_id" ON "conversation_labels" ("label_id") /*application='ClaudeHistory'*/;
CREATE UNIQUE INDEX "index_conversation_labels_on_conversation_id_and_label_id" ON "conversation_labels" ("conversation_id", "label_id") /*application='ClaudeHistory'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20260417120005'),
('20260417120004'),
('20260417120003'),
('20260417120002'),
('20260417120001'),
('20260417120000');

