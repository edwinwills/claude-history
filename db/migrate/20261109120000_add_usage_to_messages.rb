class AddUsageToMessages < ActiveRecord::Migration[8.1]
  def up
    add_column :messages, :model, :string
    add_column :messages, :api_message_id, :string
    add_column :messages, :input_tokens, :integer
    add_column :messages, :output_tokens, :integer
    add_column :messages, :cache_creation_tokens, :integer
    add_column :messages, :cache_read_tokens, :integer
    add_index :messages, :timestamp
    add_index :messages, [ :conversation_id, :api_message_id ]

    # Backfill from the raw JSONL record already stored on each assistant row.
    execute <<~SQL
      UPDATE messages SET
        model = NULLIF(json_extract(raw, '$.message.model'), '<synthetic>'),
        api_message_id = json_extract(raw, '$.message.id'),
        input_tokens = json_extract(raw, '$.message.usage.input_tokens'),
        output_tokens = json_extract(raw, '$.message.usage.output_tokens'),
        cache_creation_tokens = json_extract(raw, '$.message.usage.cache_creation_input_tokens'),
        cache_read_tokens = json_extract(raw, '$.message.usage.cache_read_input_tokens')
      WHERE record_type = 'assistant' AND json_valid(raw)
    SQL

    # Claude Code writes one JSONL record per content block, each repeating the
    # same API response's usage. Keep usage only on the last record per response.
    execute <<~SQL
      UPDATE messages SET
        input_tokens = NULL, output_tokens = NULL,
        cache_creation_tokens = NULL, cache_read_tokens = NULL
      WHERE api_message_id IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM messages m2
          WHERE m2.conversation_id = messages.conversation_id
            AND m2.api_message_id = messages.api_message_id
            AND m2.position > messages.position
        )
    SQL

    # Without stats SQLite drives stats queries from conversations instead of
    # the new timestamp index (seconds vs milliseconds).
    execute "ANALYZE"
  end

  def down
    remove_index :messages, [ :conversation_id, :api_message_id ]
    remove_index :messages, :timestamp
    remove_column :messages, :cache_read_tokens
    remove_column :messages, :cache_creation_tokens
    remove_column :messages, :output_tokens
    remove_column :messages, :input_tokens
    remove_column :messages, :api_message_id
    remove_column :messages, :model
  end
end
