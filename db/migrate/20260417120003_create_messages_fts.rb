class CreateMessagesFts < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE VIRTUAL TABLE messages_fts USING fts5(
        text_content,
        content='messages',
        content_rowid='id',
        tokenize='porter unicode61'
      );
    SQL

    execute <<~SQL
      CREATE TRIGGER messages_ai AFTER INSERT ON messages BEGIN
        INSERT INTO messages_fts(rowid, text_content) VALUES (new.id, new.text_content);
      END;
    SQL

    execute <<~SQL
      CREATE TRIGGER messages_ad AFTER DELETE ON messages BEGIN
        INSERT INTO messages_fts(messages_fts, rowid, text_content) VALUES('delete', old.id, old.text_content);
      END;
    SQL

    execute <<~SQL
      CREATE TRIGGER messages_au AFTER UPDATE ON messages BEGIN
        INSERT INTO messages_fts(messages_fts, rowid, text_content) VALUES('delete', old.id, old.text_content);
        INSERT INTO messages_fts(rowid, text_content) VALUES (new.id, new.text_content);
      END;
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS messages_au;"
    execute "DROP TRIGGER IF EXISTS messages_ad;"
    execute "DROP TRIGGER IF EXISTS messages_ai;"
    execute "DROP TABLE IF EXISTS messages_fts;"
  end
end
